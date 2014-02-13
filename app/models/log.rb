class Log
  include Mongoid::Document
  include Mongoid::Timestamps
  include StringTools

  # === CONSTANTS === #
  
  VALIDATION_STATUS_VALUES = ['incomplete', 'requested', 'withdrawn', 'validated']
  ISSUE_STATUS_VALUES = ['unissued', 'issued', 'retracted']
  
  # === RELATIONSHIPS === #

  belongs_to :badge
  belongs_to :user
  has_many :entries, dependent: :destroy

  # === FIELDS & VALIDATIONS === #

  field :validation_status,       type: String
  field :issue_status,            type: String
  field :show_on_profile,         type: Boolean
  field :private_log,             type: Boolean
  field :detached_log,            type: Boolean

  field :wiki,                    type: String
  field :wiki_sections,           type: Array
  field :wiki_versions,           type: Array
  field :tags,                    type: Array
  field :tags_with_caps,          type: Array

  field :date_started,            type: Time
  field :date_requested,          type: Time
  field :date_withdrawn,          type: Time
  field :date_issued,             type: Time
  field :date_retracted,          type: Time
  field :date_originally_issued,  type: Time
  field :date_sent_to_backpack,   type: Time

  field :validation_count,        type: Integer
  field :rejection_count,         type: Integer
  field :next_entry_number,       type: Integer
  field :current_user,            type: String # used when logging wiki_versions
  field :current_username,        type: String # used when logging wiki_versions
  field :flags,                   type: Array

  validates :badge, presence: true
  validates :user, presence: true
  validates :validation_status, inclusion: { in: VALIDATION_STATUS_VALUES, 
                                message: "%{value} is not a valid badge validation status" }
  validates :issue_status, inclusion: { in: ISSUE_STATUS_VALUES, 
                                message: "%{value} is not a valid badge issue status" }
  
  # Which fields are accessible?
  attr_accessible :show_on_profile, :private_log, :detached_log, :date_started, :date_requested, 
    :date_withdrawn, :date_sent_to_backpack, :wiki

  # === CALLBACKS === #

  before_validation :set_default_values, on: :create
  before_save :update_wiki_sections
  before_save :update_wiki_versions, on: :update # Don't store the first (default) value
  before_save :update_stati
  after_save :back_validate_if_needed
  after_save :send_notifications

  # === LOG METHODS === #

  def to_param
    user? ? user.username : _id
  end

  # Returns true if log is currently public
  # Public = Visible to everyone, Private = Visible to group admins & members
  def public?
    !private_log && (detached_log || badge.nil? || badge.group.public? || (validation_status == 'validated'))
  end

  # Adds or updates a validation entry to the log and returns it
  # NOTE: Doesn't work for new records.
  # log_validated = Boolean
  # Set overwrite_existing=false if you do NOT want to overwrite & save a existing validation
  def add_validation(creator_user, summary, body, log_validated, overwrite_existing = true)
    unless new_record?
      # First look for an existing validation for this creator (We're only allowed one per expert)
      entry = entries.find_by(creator: creator_user, type: 'validation') rescue nil

      if entry.nil?
        # First create the entry
        entry = Entry.new(summary: summary, body: body, log_validated: log_validated)
        entry.type = 'validation'
        entry.log = self
        entry.creator = creator_user
        entry.current_user = creator_user
        entry.current_username = creator_user.username
        entry.save

        # Then increment the counts
        if log_validated
          self.validation_count += 1
        else
          self.rejection_count += 1
        end
        self.next_entry_number += 1
        self.save
      elsif overwrite_existing
        # First check and see if the counts need updating because of this change
        if log_validated != entry.log_validated
          if log_validated
            self.validation_count += 1
            self.rejection_count -= 1
          else
            self.validation_count -= 1
            self.rejection_count += 1
          end
          self.save
        end

        entry.current_user = creator_user
        entry.current_username = creator_user.username
        entry.update_attributes({
          summary: summary,
          body: body,
          log_validated: log_validated
        })
      end

      return entry
    else
      return nil
    end
  end

  # Adds a post entry to the log and returns it
  # NOTE: Doesn't work for new records.
  # private = Boolean
  def add_post(creator_user, summary, body, private = false)
    unless new_record?
      # First create the post
      entry = Entry.new(summary: summary, body: body, private: private)
      entry.type = 'post'
      entry.log = self
      entry.creator = creator_user
      entry.current_user = creator_user
      entry.current_username = creator_user.username
      entry.save

      # Then update the next entry number
      self.next_entry_number += 1
      self.save
      return entry
    else
      return nil
    end
  end  

  # Returns all entries with type = 'post', sorted from newest to oldest
  # Filters out private entries based on the permissions of the passed filter_user
  # NOTE: Uses pagination
  def posts(filter_user, page = 1, page_size = APP_CONFIG['page_size_normal'])
    if filter_user && ((filter_user == user) || (!detached_log && filter_user.expert_of?(badge)))
      entries.all(type: 'post').order_by(:updated_at.desc).page(page).per(page_size)
    else
      entries.all(type: 'post', private: false).order_by(:updated_at.desc).page(page).per(page_size)
    end
  end

  # Groups posts() return by month string (Ex: "January 2014", "This Month", "Last Month")
  def posts_by_month(filter_user, page = 1, page_size = APP_CONFIG['page_size_normal'])
    return_list = []
    cur_item, cur_month_label, new_month_label = nil, nil, nil

    self.posts(filter_user, page, page_size).each do |post|
      # First set the label of the new post
      new_month_label = post.updated_at.strftime('%B %Y')
      if new_month_label == Date.today.strftime("%B %-d, %Y at %l:%M %p")
        new_month_label = "This Month"
      elsif new_month_label == (Date.today - 1.month).strftime("%B %-d, %Y at %l:%M %p")
        new_month_label = "Last Month"
      end

      if cur_month_label == new_month_label
        cur_item[:posts] << post
      else
        return_list << cur_item unless cur_item.nil? 
        cur_item = { posts: [post], label: new_month_label }
        cur_month_label = new_month_label
      end
    end

    return_list << cur_item unless cur_item.nil? 
    return_list
  end

  # Returns all entries with type = 'validation', sorted from newest to oldest
  def validations
    entries.all(type: 'validation').order_by(:updated_at.desc)
  end

protected
  
  def set_default_values
    self.date_started ||= Time.now
    self.validation_status ||= 'incomplete'
    self.issue_status ||= 'unissued'
    self.show_on_profile = true if show_on_profile.nil?
    self.private_log = false if private_log.nil?
    self.detached_log = false if detached_log.nil?
    self.wiki ||= APP_CONFIG['default_log_wiki']
    self.validation_count ||= 0
    self.rejection_count ||= 0
    self.next_entry_number = 1 if self.next_entry_number.nil?
    self.flags ||= []
  end

  # Updates validation & issue status values
  def update_stati
    if validation_count_changed? || rejection_count_changed? || date_requested_changed? \
      || date_withdrawn_changed?

      if currently_validated?
        # First update the validation status if needed
        if validation_status != 'validated'
          self.validation_status = 'validated'
        end

        # Then update the issue status if needed
        if issue_status != 'issued'
          self.issue_status = 'issued'
          self.date_issued ||= Time.now
          self.date_retracted = nil
        end
      elsif rejection_count.to_i > 0 # you can be validated w/ 0 count, but not rejected w/ 0 count
        # First update the validation status if needed
        if validation_status == 'validated'
          if date_requested.nil?
            self.validation_status = 'incomplete'
          else
            if date_withdrawn.nil?
              self.validation_status = 'requested'
            else
              self.validation_status = 'withdrawn'
            end
          end
        elsif date_withdrawn_changed? && !date_withdrawn.nil?
          self.validation_status = 'withdrawn'
        elsif date_requested_changed? && !date_requested.nil?
          self.validation_status = 'requested'
          self.date_withdrawn = nil # In case this is not their first request
        end
        
        # Then update the issue status if needed
        if issue_status == 'issued'
          self.issue_status = 'retracted'
          self.date_originally_issued = date_issued
          self.date_retracted = Time.now
          self.date_issued = nil
        end 
      end 
    end
  end

  # Checks for validation threshold problems 
  # >> (due to the threshold increasing with the addition of experts)
  # This method checks to see if the addition of SELF as an expert has increased the validation threshold.
  # If so, this method will "back-validate" all of the existing experts who are in danger of being "de-validated".
  def back_validate_if_needed
    if (validation_status == 'validated') && validation_status_changed?
      validation_threshold = badge.current_validation_threshold
      logger.debug "+++back_validate_if_needed: log user = #{user.name}, validation count = #{validation_count}, validation_threshold = #{validation_threshold}+++"
      time_string = Time.now.to_s(:full_date_time)
      
      if validation_threshold == 1
        summary = "Self-validation of badge creator"
        body = "#{user.name} created the badge on #{time_string}" \
          + " and was automatically added as an expert."
        self.add_validation(user, summary, body, true)
      else
        badge.logs.find_all do |log| 
          log.validation_status == 'validated' && (log.validation_count < validation_threshold)
        end.each do |devalidated_log|
          logger.debug "+++back_validate_if_needed: devalidated_log = #{devalidated_log.inspect}+++"
          if devalidated_log.user == self.user
            summary = "Self-validation of founding expert"
            body = "#{user.name} was added as one of the founding experts on #{time_string}."\
              + " This 'self-validation' was added automatically."
          else
            summary = "Back-validation of existing expert"
            body = "#{user.name} was added as one of the founding experts on #{time_string}."\
              + " This 'back-validation' was added automatically."
          end
          devalidated_log.add_validation(user, summary, body, true, false)
        end
      end
    end
  end

  def update_wiki_sections
    if wiki_changed?
      linkified_result = linkify_text(wiki, badge.group, badge)
      self.wiki_sections = linkified_result[:text].split(SECTION_DIVIDER_REGEX)
      self.tags = linkified_result[:tags]
      self.tags_with_caps = linkified_result[:tags_with_caps]
    end
  end

  def update_wiki_versions
    if wiki_changed?
      current_version_row = { :wiki => wiki, :user => current_user, 
                              :username => current_username, :updated_at => Time.now,
                              :updated_at_text => Time.now.strftime("%-m/%-d/%y at %l:%M%P") }

      if wiki_versions.nil? || (wiki_versions.length == 0)
        self.wiki_versions = [current_version_row]
      elsif wiki_versions.last[:wiki] != wiki
        self.wiki_versions << current_version_row
      end
    end
  end

  # This is an internal-only function that checks if the log is
  # validated based on the current threshold & counts.
  def currently_validated?
    if badge
      validation_threshold = badge.current_validation_threshold
    else
      validation_threshold = 1 # default value (for tests and such)
    end
    
    # Return value = 
    (validation_count - rejection_count) >= validation_threshold
  end

  def send_notifications
    # Note: The created_at condition is to filter out sample_data & migrations
    if validation_status_changed? && (updated_at > (Time.now - 2.hours))
      if validation_status == 'requested'
        badge.expert_logs.each do |expert_log|
          UserMailer.log_validation_request(expert_log.user, self.user, \
            badge.group, badge, self).deliver 
        end
      elsif validation_status == 'validated'
        UserMailer.log_badge_issued(user, badge.group, badge, self).deliver 
      end
    end

    if issue_status_changed? && (updated_at > (Time.now - 1.hour))
      if issue_status == 'retracted'
        UserMailer.log_badge_retracted(user, badge.group, badge, self).deliver 
      end
    end
  end

end