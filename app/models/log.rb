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

  field :date_started,            type: Time
  field :date_requested,          type: Time
  field :date_withdrawn,          type: Time
  field :date_issued,             type: Time
  field :date_retracted,          type: Time
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

  # Rerturns true if log is currently public
  def public?
    badge.group.public? || ((validation_status == 'validated') && !private_log)
  end

  # Adds a validation entry to the log
  # NOTE: Doesn't work for new records.
  # log_validated = Boolean
  # Return value = true if new validation was created, false if existing validation was updated 
  #                also returns nil if nothing was done
  def add_validation(creator_user, summary, body, log_validated)
    unless new_record?
      # First look for an existing validation for this creator (We're only allowed one per expert)
      existing_entry = entries.find_by(creator: creator_user) rescue nil

      if existing_entry
        existing_entry.update_attributes({
          summary: summary,
          body: body,
          log_validated: log_validated
        })
        return false
      else
        entry = Entry.new(summary: summary, body: body, log_validated: log_validated)
        entry.type = 'validation'
        entry.log = self
        entry.creator = creator_user
        entry.save!
        return true
      end
    else
      return nil
    end
  end

  # Adds a post entry to the log
  # NOTE: Doesn't work for new records.
  def add_post(creator_user, summary, body)
    unless new_record?
      entry = Entry.new(summary: summary, body: body)
      entry.type = 'post'
      entry.log = self
      entry.creator = creator_user
      entry.save!
    end
  end  

  # Returns all entries with type = 'post', sorted from newest to oldest
  # NOTE: Uses pagination
  def posts(page = 1, page_size = APP_CONFIG['page_size_normal'])
    entries.all(type: 'post').desc(:updated_at).page(page).per(page_size)
  end

  # Returns all entries with type = 'validation', sorted from newest to oldest
  def validations
    entries.all(type: 'validation').desc(:updated_at)
  end

protected
  
  def set_default_values
    self.date_started ||= Time.now
    self.validation_status ||= 'incomplete'
    self.issue_status ||= 'unissued'
    self.show_on_profile ||= true
    self.private_log ||= false
    self.detached_log ||= false
    self.wiki ||= APP_CONFIG['default_log_wiki']
    self.validation_count ||= 0
    self.rejection_count ||= 0
    self.next_entry_number ||= 1
    self.flags ||= []
  end

  # Updates validation & issue status values
  def update_stati
    if !currently_validated?
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
      end
      
      # Then update the issue status if needed
      if issue_status == 'issued'
        issue_status = 'retracted'
        date_retracted = Time.now
      end 
    else
      # First update the validation status if needed
      if validation_status != 'validated'
        self.validation_status = 'validated'
      end

      # Then update the issue status if needed
      if issue_status != 'issued'
        self.issue_status = 'issued'
        self.date_issued = Time.now
        self.date_retracted = nil
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
          if devalidated_log.user == self.user
            summary = "Self-validation of founding expert"
            body = "#{user.name} was added as one of the founding experts on #{time_string}."\
              + " This 'self-validation' was added automatically."
          else
            summary = "Back-validation of existing expert"
            body = "#{user.name} was added as one of the founding experts on #{time_string}."\
              + " This 'back-validation' was added automatically."
          end
          devalidated_log.add_validation(user, summary, body, true)
        end
      end
    end
  end

  def update_wiki_sections
    if wiki_changed?
      self.wiki_sections = linkify_text(wiki, badge.group, badge).split(SECTION_DIVIDER_REGEX)
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
      validation_threshold = 0 # default value (for tests and such)
    end
    
    # Return value = 
    (validation_count - rejection_count) >= validation_threshold
  end

  def send_notifications
    # Note: The created_at condition is to filter out sample_data & migrations
    if validation_status_changed? && (updated_at > (Time.now - 1.hour))
      if validation_status == 'requested'
        badge.expert_logs.each do |expert_log|
          UserMailer.log_validation_request(self.user, expert_log.user,\
            badge.group, badge, self).deliver 
        end
      elsif validation_status == 'validated'
        UserMailer.log_badge_issued(user, badge.group, badge, self)
      end
    end

    if issue_status_changed? && (updated_at > (Time.now - 1.hour))
      if issue_status == 'retracted'
        UserMailer.log_badge_retracted(user, badge.group, badge, self)
      end
    end
  end

end
