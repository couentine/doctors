class Log
  include Mongoid::Document
  include Mongoid::Timestamps
  include JSONFilter
  include JSONTemplater
  include StringTools

  # === CONSTANTS === #
  
  VALIDATION_STATUS_VALUES = ['incomplete', 'requested', 'withdrawn', 'validated']
  ISSUE_STATUS_VALUES = ['unissued', 'issued', 'retracted']
  JSON_FIELDS = [:user, :validation_status, :issue_status]
  JSON_METHODS = [:recipient, :verify]
  JSON_MOCK_FIELDS = { 'uid' => :id_string,  'badge' => :badge_url, 
    'issuedOn' => :date_issued_stamp, 'evidence' => :evidence_url }

  JSON_TEMPLATES = {
    list_item: [:id, :validation_status, :date_started, :date_requested, :date_withdrawn, 
      :date_issued, :date_retracted, :date_originally_issued, :validation_count, :rejection_count,
      :user_name, :user_username, :user_username_with_caps, :user_avatar_image_url, 
      :user_avatar_image_medium_url, :user_avatar_image_small_url, :created_at, :updated_at, 
      :validating_user_ids]
  }
  
  # === INSTANCE VARIABLES === #

  attr_accessor :context # Used to prevent certain callbacks from firing in certain contexts

  # === RELATIONSHIPS === #

  belongs_to :badge
  belongs_to :user
  has_many :entries, dependent: :destroy

  # === FIELDS & VALIDATIONS === #

  field :validation_status,                   type: String, default: 'incomplete'
  field :issue_status,                        type: String, default: 'unissued'
  field :retracted,                           type: Boolean, default: false # overrides other stati
  field :retracted_by,                        type: BSON::ObjectId
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

  field :user_name,                           type: String # local cache of user info
  field :user_username,                       type: String # local cache of user info
  field :user_username_with_caps,             type: String # local cache of user info
  field :user_email,                          type: String # local cache of user info
  field :user_avatar_image_url,               type: String # local cache of user info
  field :user_avatar_image_medium_url,        type: String # local cache of user info
  field :user_avatar_image_small_url,         type: String # local cache of user info

  field :validations_cache,                   type: Hash, default: {} # user_id => key_fields

  validates :badge, presence: true
  validates :user, presence: true
  validates :validation_status, inclusion: { in: VALIDATION_STATUS_VALUES, 
                                message: "%{value} is not a valid badge validation status" }
  validates :issue_status, inclusion: { in: ISSUE_STATUS_VALUES, 
                                message: "%{value} is not a valid badge issue status" }

  # === CALLBACKS === #

  before_validation :set_default_values, on: :create
  before_validation :keep_counts_positive
  before_create :set_user_fields
  before_save :update_wiki_sections
  before_save :update_wiki_versions, on: :update # Don't store the first (default) value
  before_save :update_stati
  after_save :send_notifications

  after_save :update_user_and_badge
  after_destroy :update_user_and_badge

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
  def embed_url(the_group=badge.group, the_badge=badge, the_user=user)
    evidence_url(the_group, the_badge, the_user) + '.embed'
  end

  def recipient
    { type: 'email', hashed: true, salt: user.identity_salt, identity: user.identity_hash }
  end

  def verify; { type: 'hosted', url: assertion_url }; end

  def id_string; id.to_s; end

  def validating_user_ids
    validations_cache.keys
  end

  # === LOG CLASS METHODS === #

  # Returns hash of the passed logs with their child posts injected as an 'posts' hash list.
  # Posts will be sorted by parent_tag asc, then by entry_number asc
  # WARNING: This method does not currently filter out posts which are private or secret due to
  #          the privacy settings of their parent tags.
  # Use the log_json_template & post_json_template options to specify the json templates used.
  def self.full_logs_as_json(log_criteria, 
      options = { log_json_template: :list_item, post_json_template: :log_item })
    log_ids, return_list = [], []
    log_map = {} # log_id => log_hash_in_return_list
    current_hash = {}

    # First loop through the queried logs and build out the return list and the log map
    log_criteria.each do |log|
      log_ids << log.id
      current_hash = log.json_from_template(options[:log_json_template])
      current_hash[:posts] = []
      log_map[log.id] = current_hash
      return_list << current_hash
    end

    # Now query for the posts, then loop through and add results into the existing list
    Entry.where(:log_id.in => log_ids, :type => 'post').order_by(:parent_tag.asc, 
        :entry_number.asc).each do |entry|
      log_map[entry.log_id][:posts] << entry.json_from_template(options[:post_json_template])
    end

    return_list
  end

  # === LOG CLASS ASYNC METHODS === #

  # Runs the add_validation method on the logs belonging to the users with all of the passed 
  # usernames for the specified badge. (Invalid usernames will be ignored.)
  # Returns a poller id if run in async mode
  def self.add_validations(badge_id, log_usernames, creator_user_id, summary, body, logs_validated, 
      overwrite_existing = true, async = false)
    if async
      poller = Poller.new
      poller.waiting_message = "Posting feedback for #{log_usernames.count} logs..."
      poller.progress = 0 # this will put the poller into 'progress mode'
      poller.data = { badge_id: badge_id.to_s, log_usernames: log_usernames, 
        creator_user_id: creator_user_id.to_s, summary: summary, body: body, 
        logs_validated: logs_validated, overwrite_existing: overwrite_existing }
      poller.save

      Log.delay.do_add_validations(badge_id, log_usernames, creator_user_id, 
        summary, body, logs_validated, overwrite_existing, poller.id)

      poller.id
    else
      Log.do_add_validations(badge_id, log_usernames, creator_user_id, summary, body, 
        logs_validated, overwrite_existing)
    end
  end

  def self.do_add_validations(badge_id, log_usernames, creator_user_id, summary, body, 
      logs_validated, overwrite_existing = true, poller_id = nil)
    begin
      # Query for the core records
      poller = Poller.find(poller_id) rescue nil
      creator_user = User.find(creator_user_id)
      badge = Badge.find(badge_id)
      logs = badge.logs.where(:user_username.in => log_usernames)

      # Initialize vars
      log_count = logs.count
      progress_count = 0
      
      # Now loop through and add the validations
      logs.each do |log|
        log.context = 'bulk_validation' # this skips the updating of the badge validation count
        log.add_validation(creator_user, summary, body, logs_validated, overwrite_existing)
        progress_count += 1

        # Update the badge in memory (since we're suppressing the log callback that does this)
        if log.validation_status == 'validated'
          badge.expert_user_ids << log.user_id unless badge.expert_user_ids.include? log.user_id
          badge.learner_user_ids.delete log.user_id if badge.learner_user_ids.include? log.user_id
        else
          badge.expert_user_ids.delete log.user_id if badge.expert_user_ids.include? log.user_id
          badge.learner_user_ids << log.user_id unless badge.learner_user_ids.include? log.user_id
        end

        if poller
          poller.progress = progress_count * 100 / log_count
          poller.save if poller.changed? # don't hit the DB unless the number has changed
        end
      end

      # Now we need to update the parts of the badge that didn't get updated 
      badge.update_validation_request_count
      badge.timeless.save if badge.changed?

      if poller
        poller.status = 'successful'
        poller.message = "Feedback has been successfully posted to #{log_count} logs."
        poller.save
      end
    rescue Exception => e
      if poller
        poller.status = 'failed'
        poller.message = 'An error occurred while trying to post feedback, ' \
          + "please try again. (Error message: #{e})"
        poller.save
      else
        throw e
      end
    end
  end

  # If log still exists then pass only the first param
  # If log is deleted then leave log_id blank and pass user_id AND badge_id instead
  def self.update_user(log_id, user_id = nil, badge_id = nil)
    # First query the records
    if log_id
      log = Log.find(log_id)
      user = log.user
      badge = log.badge
    else
      log = nil
      user = User.find(user_id)
      badge = Badge.find(badge_id)
    end
    
    # Then update the badge list fields on the user record
    if log && !log.detached_log
      user.all_badge_ids << badge.id unless user.all_badge_ids.include? badge.id

      if log.validation_status == 'validated'
        user.expert_badge_ids << badge.id unless user.expert_badge_ids.include? badge.id
        user.learner_badge_ids.delete badge.id if user.learner_badge_ids.include? badge.id
      else
        user.expert_badge_ids.delete badge.id if user.expert_badge_ids.include? badge.id
        user.learner_badge_ids << badge.id unless user.learner_badge_ids.include? badge.id
      end
    else
      user.all_badge_ids.delete badge.id if user.all_badge_ids.include? badge.id
      user.expert_badge_ids.delete badge.id if user.expert_badge_ids.include? badge.id
      user.learner_badge_ids.delete badge.id if user.learner_badge_ids.include? badge.id
    end

    user.timeless.save if user.changed?
  end

  # If log still exists then pass only the first param
  # If log is deleted then leave log_id blank and pass badge_id AND user_id
  # NOTE: The parameter order is reversed in this method versus the one above.
  def self.update_badge(log_id, badge_id = nil, user_id = nil)
    # First query the records
    if log_id
      log = Log.find(log_id)
      user = log.user
      badge = log.badge
    else
      log = nil
      user = User.find(user_id)
      badge = Badge.find(badge_id)
    end
    
    # Then update the badge list fields on the user record
    if log && !log.detached_log
      badge.all_user_ids << user.id if !badge.all_user_ids.include?(user.id)

      if log.validation_status == 'validated'
        badge.expert_user_ids << user.id unless badge.expert_user_ids.include? user.id
        badge.learner_user_ids.delete user.id if badge.learner_user_ids.include? user.id
      else
        badge.expert_user_ids.delete user.id if badge.expert_user_ids.include? user.id
        badge.learner_user_ids << user.id unless badge.learner_user_ids.include? user.id
      end
    else
      badge.all_user_ids.delete user.id if badge.all_user_ids.include? user.id
      badge.expert_user_ids.delete user.id if badge.expert_user_ids.include? user.id
      badge.learner_user_ids.delete user.id if badge.learner_user_ids.include? user.id
    end

    badge.update_validation_request_count
    badge.timeless.save if badge.changed?
  end

  # === LOG INSTANCE METHODS === #

  def to_param
    if user_username_with_caps
      user_username_with_caps
    elsif user
      user.username_with_caps
    else
      _id.to_s
    end
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

  # Use this method instead of setting the boolean directly
  # Returns false if there was a problem, true if ok
  def add_retraction(creator_user)
    self.retracted = true
    self.retracted_by ||= creator_user.id
    self.save
  end

  # Use this method instead of setting the boolean directly
  # Returns false if there was a problem, true if ok
  def clear_retraction
    self.retracted = false
    self.retracted_by = nil
    self.save
  end

  # Adds or updates a validation entry to the log and returns it
  # Also updates log validations cache
  # NOTE: Doesn't work for new records.
  # log_validated = Boolean
  # Set overwrite_existing=false if you do NOT want to overwrite & save a existing validation
  def add_validation(creator_user, summary, body, log_validated, overwrite_existing = true)
    unless new_record?
      # First look for an existing validation for this creator (We're only allowed one per expert)
      entry = entries.find_by(creator: creator_user, type: 'validation') rescue nil

      if entry.nil?
        # First create the entry
        entry = Entry.new
        entry.summary = summary
        entry.body = body
        entry.log_validated = log_validated
        entry.type = 'validation'
        entry.log = self
        entry.creator = creator_user
        entry.current_user = creator_user
        entry.current_username = creator_user.username
        entry.context = 'log_add_validation' # prevent callback from updating the log
        entry.save

        # Then update the validations cache
        self.validations_cache[creator_user.id.to_s] = {
          'entry_id' => entry.id,
          'log_validated' => log_validated,
          'summary' => summary,
          'body' => body
        }

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
        end

        # Then update the validations cache and save
        self.validations_cache[creator_user.id.to_s] = {
          'entry_id' => entry.id,
          'log_validated' => log_validated,
          'summary' => summary,
          'body' => body
        }
        self.save

        entry.current_user = creator_user
        entry.current_username = creator_user.username
        entry.summary = summary
        entry.body = body
        entry.log_validated = log_validated
        
        entry.save if entry.changed?
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
  # and values = the number of items posted to that requirement
  # Pass badge_requirements in if desired to save a query
  def requirements_counts(badge_requirements = nil)
    requirement_map = {}
    requirement_id_list = []

    if badge_id
      # First initialize the topic map with everything set to false
      if badge_requirements.nil?
        badge_requirements = Tag.where(badge_id: badge_id, type: 'requirement').asc(:sort_order)
      end
      badge_requirements.each do |tag| 
        requirement_map[tag.id] = 0
        requirement_id_list << tag.id
      end

      # Then run through and log any entries which've been posted to the requirements
      entries.where(type: 'post', :tag_id.in => requirement_id_list).each do |entry|
        requirement_map[entry.tag_id] += 1
      end
    end

    # return value = 
    requirement_map
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

  # This updates all of the user info cache fields on the log from the supplied user record
  def update_user_fields_from(user_record)
    self.user_name = user_record.name
    self.user_username = user_record.username
    self.user_username_with_caps = user_record.username_with_caps
    self.user_email = user_record.email
    self.user_avatar_image_url = user_record.avatar_image_url
    self.user_avatar_image_medium_url = user_record.avatar_image_medium_url
    self.user_avatar_image_small_url = user_record.avatar_image_small_url
  end

  # === ASYNC CLASS METHODS === #

  # This is called by send_notifications above in order to async the queueing of potentially
  # hundreds of emails
  def self.do_send_validation_requests(validated_log_id)
    # Query the log & badge
    validated_log = Log.find(validated_log_id)
    badge = validated_log.badge
    
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
      unless user_to_email.email_inactive
        UserMailer.delay.log_validation_request(user_to_email.id, validated_log.user.id, \
          badge.group_id, badge.id, validated_log.id) 
      end
    end
  end

protected
  
  def set_default_values
    self.date_started ||= Time.now
  end

  def keep_counts_positive
    self.validation_count = 0 if validation_count < 0
    self.rejection_count = 0 if rejection_count < 0
  end

  def set_user_fields
    update_user_fields_from user
  end

  # Updates validation & issue status values
  # NOTE: If retracted is set then we will not issue the badge until it is cleared.
  def update_stati
    if validation_count_changed? || rejection_count_changed? || retracted_changed? \
        || date_requested_changed? || date_withdrawn_changed? 
      
      if retracted
        # First update the validation status if needed
        if validation_status == 'validated'
          self.validation_status = 'incomplete'
        end
        
        # Then update the issue status if needed
        if issue_status == 'issued'
          self.issue_status = 'retracted'
          self.date_originally_issued = date_issued
          self.date_retracted = Time.now
          self.date_issued = nil
        end 
      else
        if issue_status == 'retracted'
          self.issue_status = 'unissued'
          self.date_retracted = nil
          self.retracted_by = nil
        end
        
        if currently_validated?
          # First update the validation status if needed
          if validation_status != 'validated'
            self.validation_status = 'validated'
          end

          # Then update the issue status if needed
          if issue_status != 'issued'
            self.issue_status = 'issued'
            self.date_issued ||= Time.now

            set_flag 'first_view_after_issued'
          end
        elsif date_withdrawn_changed? && !date_withdrawn.nil?
          self.validation_status = 'withdrawn'
        elsif date_requested_changed? && !date_requested.nil?
          self.validation_status = 'requested'
          self.date_withdrawn = nil # In case this is not their first request
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
    # Set to badge value or default value (for tests and such)
    validation_threshold = (badge) ? badge.validation_threshold : 1
    
    # Return value = 
    ([validation_count, 0].max - [rejection_count, 0].max) >= [validation_threshold, 1].max
  end

  
  # Call this from after save and after destroy
  # This method checks to see if we need to update the user OR badge records via sidekiq.
  # Things that need updating: User lists of expert/learner/all badges, Badge lists of 
  # experts/learners/members, Badge validation request count
  # List of update cases:
  # - If we are being created or destroyed >> Update user and badge
  # - If we are entering or exiting valdiated validation_status >> Update user and badge
  # - If we are entering or exiting detached state >> Update user and badge
  # - If we are entering or exiting requested validation_status >> Update badge
  def update_user_and_badge
    log_id = (destroyed?) ? nil : id

    user_needs_update = new_record? || destroyed? || detached_log_changed? \
      || (validation_status_changed? \
          && ((validation_status == 'validated') || (validation_status_was == 'validated')))
    
    badge_needs_update = !context.in?(['bulk_validation', 'badge_add']) &&
      (user_needs_update || (validation_status_changed? \
        && ((validation_status == 'requested') || (validation_status_was == 'requested'))))

    Log.delay.update_user(log_id, user_id, badge_id) if user_needs_update
    Log.delay(queue: 'low').update_badge(log_id, badge_id, user_id) if badge_needs_update
  end

  def send_notifications
    # Note: The created_at condition is to filter out sample_data & migrations
    if validation_status_changed? && (updated_at > (Time.now - 2.hours))
      if (validation_status == 'requested') && badge.send_validation_request_emails && !retracted
        Log.delay(queue: 'mailer').do_send_validation_requests(id)
      elsif validation_status == 'validated'
        unless user.email_inactive
          UserMailer.delay.log_badge_issued(user.id, badge.group_id, badge.id, self.id) 
        end
      end
    end

    if issue_status_changed? && (updated_at > (Time.now - 1.hour))
      if issue_status == 'retracted'
        unless user.email_inactive
          UserMailer.delay.log_badge_retracted(user.id, badge.group_id, badge.id, self.id) 
        end
        
        # Update analytics
        IntercomEventWorker.perform_async({
          'event_name' => 'badge-retracted',
          'email' => user.email,
          'created_at' => Time.now.to_i,
          'metadata' => {
            'badge_id' => badge.id.to_s,
            'badge_name' => badge.name,
            'badge_url' => badge.badge_url
          }
        })
      end
    end
  end

end
