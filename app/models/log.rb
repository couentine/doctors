class Log
  include Mongoid::Document
  include Mongoid::Timestamps
  include JSONFilter
  include StringTools

  # === CONSTANTS === #
  
  VALIDATION_STATUS_VALUES = ['incomplete', 'requested', 'withdrawn', 'validated']
  ISSUE_STATUS_VALUES = ['unissued', 'issued', 'retracted']
  JSON_FIELDS = [:user, :validation_status, :issue_status]
  JSON_METHODS = [:recipient, :verify]
  JSON_MOCK_FIELDS = { 'uid' => :_id,  'badge' => :badge_url, 'issuedOn' => :date_issued_stamp,
    'evidence' => :evidence_url }
  
  # === RELATIONSHIPS === #

  belongs_to :badge
  belongs_to :user
  has_many :entries, dependent: :destroy

  # === FIELDS & VALIDATIONS === #

  field :validation_status,                   type: String, default: 'incomplete'
  field :issue_status,                        type: String, default: 'unissued'
  field :show_on_profile,                     type: Boolean, default: true
  field :detached_log,                        type: Boolean, default: false
  field :receive_validation_request_emails,   type: Boolean, default: true

  field :wiki,                                type: String, default: APP_CONFIG['default_log_wiki']
  field :wiki_sections,                       type: Array
  field :wiki_versions,                       type: Array
  field :tags,                                type: Array
  field :tags_with_caps,                      type: Array

  field :date_started,                        type: Time
  field :date_requested,                      type: Time
  field :date_withdrawn,                      type: Time
  field :date_issued,                         type: Time
  field :date_retracted,                      type: Time
  field :date_originally_issued,              type: Time
  field :date_sent_to_backpack,               type: Time

  field :validation_count,                    type: Integer, default: 0
  field :rejection_count,                     type: Integer, default: 0
  field :next_entry_number,                   type: Integer, default: 1
  field :current_user,                        type: String # used when logging wiki_versions
  field :current_username,                    type: String # used when logging wiki_versions
  field :flags,                               type: Array, default: []

  validates :badge, presence: true
  validates :user, presence: true
  validates :validation_status, inclusion: { in: VALIDATION_STATUS_VALUES, 
                                message: "%{value} is not a valid badge validation status" }
  validates :issue_status, inclusion: { in: ISSUE_STATUS_VALUES, 
                                message: "%{value} is not a valid badge issue status" }
  
  # Which fields are accessible?
  attr_accessible :show_on_profile, :detached_log, :date_started, :date_requested, 
    :date_withdrawn, :date_sent_to_backpack, :wiki, :receive_validation_request_emails

  # === CALLBACKS === #

  before_validation :set_default_values, on: :create
  before_save :update_wiki_sections
  before_save :update_wiki_versions, on: :update # Don't store the first (default) value
  before_save :update_stati
  after_save :back_validate_if_needed
  after_save :send_notifications

  # === LOG MOCK FIELD METHODS === #
  # These are used to mock the presence of certain fields in the JSON output.

  def date_issued_stamp; (date_issued.nil?) ? '' : date_issued.to_i; end
  def badge_url; "#{ENV['root_url']}/#{badge.group.url}/#{badge.url}.json"; end
  def badge_image_url; "#{ENV['root_url']}/#{badge.group.url}/#{badge.url}.png"; end
  def assertion_url(the_group=badge.group, the_badge=badge, the_user=user)
    "#{ENV['root_url']}/#{the_group.url}/#{the_badge.url}/o/#{the_user.username}.json"
  end

  def evidence_url(the_group=badge.group, the_badge=badge, the_user=user)
    "#{ENV['root_url']}/#{the_group.url}/#{the_badge.url}/u/#{the_user.username}"
  end

  def recipient
    { type: 'email', hashed: true, salt: user.identity_salt, identity: user.identity_hash }
  end

  def verify; { type: 'hosted', url: assertion_url }; end

  # === LOG METHODS === #

  def to_param
    user? ? user.username : _id
  end

  def set_flag(flag)
    self.flags << flag unless flags.include? flag
  end

  def clear_flag(flag)
    self.flags.delete flag if flags.include? flag
  end

  def has_flag?(flag)
    flags.include? flag
  end

  def has_profile?
    !wiki_versions.blank? && !wiki.blank?
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

  # Returns the full content of all of this log's posts, organized by topic
  #   'tag' => the_tag_record_itself || nil
  #   'entries' => a_list_of_all_entries }
  def posts_by_topic()
    topic_list = [] # this is the return list
    topic_item_map = {} # this is a map to keep track of the list contents while we're building it
    
    if badge_id
      # First query and sort the tags appropriately (requirements first, then the rest)
      # Use that to seed the topic_list since it will be the master list for the order
      Tag.where(badge_id: badge_id).order_by(:type.asc, :sort_order.asc, :name.asc).each do |tag|
        topic_item = { 'tag' => tag, 'entries' => [] }
        topic_list << topic_item
        topic_item_map[tag.id] = topic_item
      end

      # Now add a null item (for etcetera)... it's the last one so it's easy to find
      topic_list << { 'tag' => nil, 'entries' => [] }

      # Run through all of the posts and add them to the list
      entries.where(type: 'post').each do |entry|
        topic_item = topic_item_map[entry.tag_id] || topic_list.last
        topic_item['entries'] << entry
      end

      # Finally we just need to run through the list and cleanse any wiki pages without entries
      topic_list = topic_list.select do |item| 
        !item['entries'].blank? || (item['tag'] && (item['tag'].type == 'requirement'))
      end
    end

    # return value = 
    topic_list
  end

  # Returns a map with keys = each of the badge requirement tag ids
  # and values = true / false indicating whether that requirement is complete
  # Pass badge_requirements in if desired to save a query
  def requirements_complete(badge_requirements = nil)
    requirement_map = {}
    requirement_id_list = []

    if badge_id
      # First initialize the topic map with everything set to false
      if badge_requirements.nil?
        badge_requirements = Tag.where(badge_id: badge_id, type: 'requirement').asc(:sort_order)
      end
      badge_requirements.each do |tag| 
        requirement_map[tag.id] = false
        requirement_id_list << tag.id
      end

      # Then run through and log any entries which've been posted to the requirements
      entries.where(type: 'post', :tag_id.in => requirement_id_list).each do |entry|
        requirement_map[entry.tag_id] = true
      end
    end

    # return value = 
    requirement_map
  end

  # Returns all entries with type = 'validation', sorted from newest to oldest
  def validations
    entries.where(type: 'validation').desc(:updated_at)
  end

protected
  
  def set_default_values
    self.date_started ||= Time.now
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

          set_flag 'first_view_after_issued'
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
        end
        
        # Then update the issue status if needed
        if issue_status == 'issued'
          self.issue_status = 'retracted'
          self.date_originally_issued = date_issued
          self.date_retracted = Time.now
          self.date_issued = nil
        end 
      elsif date_withdrawn_changed? && !date_withdrawn.nil?
        self.validation_status = 'withdrawn'
      elsif date_requested_changed? && !date_requested.nil?
        self.validation_status = 'requested'
        self.date_withdrawn = nil # In case this is not their first request
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
      
      if badge.expert_logs.count <= 1
        summary = "Self-validation of badge creator"
        body = "#{user.name} created the badge on #{time_string}" \
          + " and was automatically awarded the badge."
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
    if wiki_changed? && (wiki != APP_CONFIG['default_log_wiki'])
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
      if (validation_status == 'requested') && badge.send_validation_request_emails
        # Requests go out to all admins and (depending on awardability setting) any expert who
        # has not opted out
        user_ids_to_email = badge.group.admin_ids.clone

        # First get all expert logs and run through them
        badge.logs.where(validation_status: 'validated', detached_log: false).each do |log|
          if user_ids_to_email.include? log.user_id # then just check if they've opted out
            user_ids_to_email.delete log.user_id unless log.receive_validation_request_emails
          else # then just check if we're awarding to non-admin experts
            user_ids_to_email << log.user_id if badge.awardability == 'experts'
          end
        end

        # Now query the users and send them each an email
        User.where(:id.in => user_ids_to_email).each do |user_to_email|
          UserMailer.log_validation_request(user_to_email, self.user, badge.group, badge, \
            self).deliver 
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
