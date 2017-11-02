class Entry
  include Mongoid::Document
  include Mongoid::Timestamps
  include JSONFilter
  include JSONTemplater
  include StringTools

  # === CONSTANTS === #
  
  MAX_SUMMARY_LENGTH = 140
  TYPE_VALUES = ['post', 'validation']
  FORMAT_VALUES = ['text', 'link', 'image', 'file', 'tweet', 'code']
  JSON_FIELDS = [:log, :creator, :parent_tag, :entry_number, :summary, :type, :log_validated, :body_sections, :tags, :tags_with_caps]

  JSON_TEMPLATES = {
    log_item: [:id, :entry_number, :created_at, :updated_at, :summary, :body, :linkified_summary, :type, :format, :format_icon, 
      :parent_tag, :body_sections, :preserve_body_html, :link_url, :code_format, :link_metadata, :image_url, :image_medium_url, 
      :image_small_url, :image_processing_error, :file_url, :file_processing_error, { uploaded_file_filename: :file_filename }]
  }
  
  # === INSTANCE VARIABLES === #

  attr_accessor :context # Used to prevent certain callbacks from firing in certain contexts

  # === RELATIONSHIPS === #

  belongs_to :log
  belongs_to :tag
  belongs_to :creator, inverse_of: :created_entries, class_name: "User"

  # === FIELDS & VALIDATIONS === #

  field :entry_number,                    type: Integer
  field :summary,                         type: String
  field :linkified_summary,               type: String
  field :private,                         type: Boolean, default: false
  field :type,                            type: String
  field :format,                          type: String, default: 'any'
  field :log_validated,                   type: Boolean
  field :parent_tag,                      type: String

  field :body,                            type: String
  field :preserve_body_html,              type: Boolean, default: false # set this to use the newer style (body is sanitized and left as is)
  field :link_url,                        type: String
  field :link_metadata,                   type: Hash, default: {}, pre_processed: true
  field :code_format,                     type: String
  field :body_versions,                   type: Array, default: []
  field :body_sections,                   type: Array, default: []
  field :tags,                            type: Array, default: []
  field :tags_with_caps,                  type: Array, default: []

  field :current_user,                    type: String
  field :current_username,                type: String
  field :flags,                           type: Array

  mount_uploader :direct_uploaded_image,  S3DirectUploader
  mount_uploader :uploaded_image,         S3Uploader
  field :uploaded_image_key,              type: String
  field :processing_uploaded_image,       type: Boolean
  field :image_processing_error,          type: Boolean

  mount_uploader :direct_uploaded_file,   S3DirectFileUploader
  mount_uploader :uploaded_file,          S3FileUploader
  field :uploaded_file_key,               type: String
  field :processing_uploaded_file,        type: Boolean
  field :file_processing_error,           type: Boolean

  # === UNIVERSAL VALIDATIONS === #
  validates :log, presence: true
  validates :creator, presence: true
  validates :entry_number, presence: true, uniqueness: { scope: :log }
  validates :type, inclusion: { in: TYPE_VALUES, message: "%{value} is not a valid entry type" }

  # === FORMAT-SPECIFIC VALIDATIONS === #
  validates :summary, presence: true, length: { within: 3..MAX_SUMMARY_LENGTH }, \
    if: :summary_is_required?
  validates :body, presence: true, if: :body_is_required?
  validates :link_url, presence: true, format: { with: HTTP_URL_REGEX, \
    message: 'must be a valid link (remember the http)' }, if: :link_is_required?
  validates :uploaded_image_key, presence: true, if: :image_is_required?
  validates :uploaded_file_key, presence: true, if: :file_is_required?
  validates :link_url, format: { with: TWITTER_URL_REGEX, message: "must be a valid Twitter url" },\
    if: :tweet_is_required?

  # === CALLBACKS === #

  before_validation :set_default_values, on: :create
  before_validation :update_image_key
  before_validation :update_file_key
  before_save :process_parent_tag_and_content_changes
  before_save :update_body_versions # DO store the first value since it comes from the user
  after_save :process_image
  after_save :process_file
  after_save :process_link
  after_save :process_tweet
  after_create :update_log
  after_create :send_notifications
  after_destroy :check_log_validation_counts

  before_save :update_analytics
  
  # === ENTRY MOCK FIELD METHODS === #

  def image_url(version = nil)
    uploaded_image_url(version)
  end
  def image_medium_url; image_url(:preview); end
  def image_small_url; image_url(:thumb); end

  def file_url
    uploaded_file_url
  end


  # === ENTRY METHODS === #

  def to_param
    entry_number.to_s || _id.to_s
  end

  # Validation methods
  def summary_is_required?
    ['text', nil, 'link', 'file', 'code'].include? format
  end
  
  def body_is_required?
    format == 'code'
  end
  
  def link_is_required?
    ['link', 'tweet'].include? format
  end
  
  def image_is_required?
    format == 'image'
  end
  
  def file_is_required?
    format == 'file'
  end
  
  def tweet_is_required?
    format == 'tweet'
  end
  

  # Returns the font awesome icon code for this tag's format (ex: "fa-camera")
  def format_icon
    case format
    when 'any'
      # NOTE: This is not a valid format for entries, but it is used to display the format
      # selector so it needs to be able to display an icon in some cases.
      icon_text = 'fa-asterisk'
    when 'link'
      icon_text = 'fa-link'
    when 'tweet'
      icon_text = 'fa-twitter'
    when 'image'
      icon_text = 'fa-camera'
    when 'file'
      icon_text = 'fa-file'
    when 'code'
      icon_text = 'fa-code'
    else
      icon_text = 'fa-pencil'
    end
  end

  # Returns a number representing the updated_at date relative to the learner's start date
  # Example: if updated_at == log.date_started, return = 1 (learner's first week)
  def learner_week_updated_at
    ((updated_at.to_date - log.date_started.to_date).to_f / 3600 / 7).ceil
  end
  def learner_week_created_at
    ((created_at.to_date - log.date_started.to_date).to_f / 3600 / 7).ceil
  end

  # Returns the privacy level of the parent tag OR if the parent tag is unset, returns 'public'
  def privacy
    if tag_id.nil?
      return 'public'
    elsif tag.nil?
      return 'public'
    else
      return tag.privacy
    end
  end

  # Uses the group and tag visibility to determine if this user can see the log entry
  # The entry is always visible to its creator and the owner of the log
  # NOTE: It's ok if user is nil
  #       Provide badge in order to save a query. (Only used if privacy = secret)
  def visible_to?(user, badge = nil)
    if !user.nil? && ((user.id == log.user_id) || (user.id == creator_id))
      return true
    elsif privacy == 'secret'
      badge = tag.badge unless badge
      return !user.nil? && (user.admin_of?(tag.badge.group) \
        || ((badge.awardability == 'experts') && user.expert_of?(tag.badge)))
    elsif privacy == 'private'
      return !user.nil? && (user.member_of?(tag.badge.group) || user.admin_of?(tag.badge.group))
    else
      return true
    end
  end

  # Extracts the filename from the `uploaded_image_key` if present
  def uploaded_image_filename
    if uploaded_image_key.present? && uploaded_image_key.include?('/')
      uploaded_image_key.split('/').last
    else
      nil
    end
  end

  # Extracts the filename from the `uploaded_file_key` if present
  def uploaded_file_filename
    if uploaded_file_key.present? && uploaded_file_key.include?('/')
      uploaded_file_key.split('/').last
    else
      nil
    end
  end

  # === ASYNC METHODS === #

  def self.refresh_link(entry_id, timeless_save = false)
    entry = Entry.find(entry_id)

    begin
      # Now attempt to pull down link info from the Embed.ly API
      result = $embedly.oembed(url: entry.link_url)
      
      # Now that we have the result we convert it to a hash (the fields are in the 'table' key)
      if !result.blank? && result.first && !result.first.as_json['table'].blank?
        entry.link_metadata = result.first.as_json['table']
      end

      # Save it inside of the rescue block just in case another error creeps in
      if timeless_save
        entry.timeless.save!
      else
        entry.save!
      end
    rescue Exception => e
      # Save the error in the link meta data
      entry.link_metadata = {
        'embedly_exception' => e.to_s
      }
      entry.save!

      # Then throw the error so it is retried by sidekiq
      throw e
    end
  end

  # Call this function from a console to recursively refresh links on all entries in the DB where
  # link_metadata['type'] is nil. This method uses sidekiq to spread itself out into batches run
  # once per second. Each batch contains 2/3rds of EMBEDLY_RATE_LIMIT.
  # Specify stop_after to have the process stop after a certain number of entries.
  # To keep running until all of the links are populated set stop_after to -1.
  # NOTE: If all of the attempts throw an error then the method will fail and throw the last error.
  def self.refresh_blank_links(stop_after, current_count = 0)
    # Initialize the variables
    error_count = 0
    last_error = nil
    batch_size = (ENV['EMBEDLY_RATE_LIMIT'] || 15) * 2 / 3

    # Build the batch query (randomly sample so we don't get stuck if there are bad ones)
    entry_batch = Entry.where(format: 'link', 'link_metadata.type' => nil).sample(batch_size)
    batch_count = entry_batch.count

    entry_batch.each do |entry|
      begin
        Entry.refresh_link(entry.id, true) # timeless_save = true
      rescue Exception => e
        error_count += 1
        last_error = e
      end
    end

    # Now increment the count and schedule the next run if needed
    current_count += batch_count
    if (error_count > 0) && (error_count == batch_count)
      # If everything was an error, stop the train
      throw last_error
    elsif (batch_count > 0) && ((stop_after < 0) || (current_count < stop_after))
      Entry.delay_for(1.second).refresh_blank_links(stop_after, current_count)
    end
  end

  def self.refresh_tweet(entry_id)
    entry = Entry.find(entry_id)

    begin
      # Now attempt to pull down the tweet body using the twitter API
      tweet_id = StringTools.extract_tweet_id(entry.link_url)
      tweet = $twitter.status(tweet_id)
      entry.summary = tweet.text

      # Now that we have the tweet, let's store some metadata
      entry.link_metadata = {
        'tweet_id' => tweet.id,
        'tweet_favorite_count' => tweet.favorite_count,
        'tweet_filter_level' => tweet.filter_level,
        'tweet_in_reply_to_screen_name' => tweet.in_reply_to_screen_name,
        'tweet_in_reply_to_status_id' => tweet.in_reply_to_status_id,
        'tweet_in_reply_to_user_id' => tweet.in_reply_to_user_id,
        'tweet_lang' => tweet.lang,
        'tweet_retweet_count' => tweet.retweet_count,
        'tweet_source' => tweet.source,
        'tweet_text' => tweet.text,
        'tweet_user_id' => tweet.user.id,
        'tweet_user_screen_name' => tweet.user.screen_name,
        'tweet_user_connections' => tweet.user.connections,
        'tweet_user_description' => tweet.user.description,
        'tweet_user_favourites_count' => tweet.user.favourites_count,
        'tweet_user_followers_count' => tweet.user.followers_count,
        'tweet_user_friends_count' => tweet.user.friends_count,
        'tweet_user_lang' => tweet.user.lang,
        'tweet_user_listed_count' => tweet.user.listed_count,
        'tweet_user_location' => tweet.user.location,
        'tweet_user_name' => tweet.user.name,
        'tweet_user_statuses_count' => tweet.user.statuses_count,
        'tweet_user_time_zone' => tweet.user.time_zone,
        'tweet_user_utc_offset' => tweet.user.utc_offset
      }

      # Switch out the instances of Twitter::NullObject (they cause an IO error on save)
      entry.link_metadata.each do |key, value|
        entry.link_metadata[key] = nil if value.nil? && (value != nil)
      end

      # Save it inside of the rescue block just in case another error creeps in
      entry.save!
    rescue Exception => e
      # Nothing found so rather than throw an error we'll just set the summary to an error value.
      entry.summary = "No tweet found! Please check the link and try again." 
      entry.link_metadata = {
        'tweet_exception' => e.to_s
      }
      entry.save!
    end
  end

protected
  
  def set_default_values
    self.entry_number ||= log.next_entry_number if log
    self.format = 'text' if type == 'validation'
  end

  # Sets tag relationship based on parent_tag string
  # This also does format-specific processing 
  #   (since this is the only callback that's sure of the format on a new entry)
  def process_parent_tag_and_content_changes
    if !parent_tag.blank? && parent_tag_changed? && !log.badge_id.nil?
      matched_tags = Tag.where(badge: log.badge_id, name: parent_tag.downcase)
      if matched_tags.count > 0
        self.tag = matched_tags.first
        self.format = tag.format if tag.format != 'any'
      else
        t = Tag.new
        t.badge = log.badge_id
        t.name_with_caps = parent_tag
        t.name = parent_tag.downcase
        t.wiki = ''
        t.current_user = current_user
        t.current_username = current_username
        t.display_name = detagify_string(t.name_with_caps)
        t.save
        self.tag = t
        self.format = tag.format
      end
    end
    
    if (format == 'tweet') && link_url_changed? && !link_url.blank?
      self.link_url = link_url.strip
      self.summary = 'Loading tweet, refresh to view...'
      self.link_metadata = {}
    end

    if (format == 'link') && link_url_changed? && !link_url.blank?
      # Transform special links into other sorts of embeds
      self.link_url = link_url.strip
      self.body = transform_link link_url
    end

    if body_changed? || summary_changed? || link_url_changed?
      # Linkify summary
      summary_result = linkify_text(summary, log.badge.group, log.badge)
      self.linkified_summary = summary_result[:text] if summary_changed?
      
      # Either sanitize the body html or linkify it and split it into sections
      if preserve_body_html
        html_sanitizer = Rails::Html::WhiteListSanitizer.new
        self.body = html_sanitizer.sanitize(body)
        self.body_sections = [body]
      else
        body_result = linkify_text(body, log.badge.group, log.badge)
        self.body_sections = body_result[:text].split(SECTION_DIVIDER_REGEX) if body_changed?
      end
      
      # The entry tags should be a concatenation of the summary and body tags
      self.tags = summary_result[:tags]
      self.tags = (tags + body_result[:tags]).uniq if body_result.present?
      self.tags_with_caps = summary_result[:tags_with_caps]
      self.tags_with_caps = (tags_with_caps + body_result[:tags_with_caps]).uniq if body_result.present?
    end
  end

  def update_body_versions
    if body_changed?
      current_version_row = { :body => body, :user => current_user, 
                              :username => current_username, :updated_at => Time.now,
                              :updated_at_text => Time.now.strftime("%-m/%-d/%y at %l:%M%P") }

      if body_versions.blank?
        self.body_versions = [current_version_row]
      elsif body_versions.last[:body] != body
        self.body_versions << current_version_row
      end
    end
  end

  def update_image_key
    if uploaded_image_key_changed? && uploaded_image_key.present?
      self.direct_uploaded_image.key = uploaded_image_key
      self.processing_uploaded_image = true
    end
  end

  def update_file_key
    if uploaded_file_key_changed? && uploaded_file_key.present?
      self.direct_uploaded_file.key = uploaded_file_key
      self.processing_uploaded_file = true
    end
  end

  def process_image
    if processing_uploaded_image_changed? && processing_uploaded_image
      Entry.delay(queue: 'high', retry: 10).do_process_image(id)
    end
  end

  def process_file
    if processing_uploaded_file_changed? && processing_uploaded_file
      Entry.delay(queue: 'high', retry: 10).do_process_file(id)
    end
  end

  def process_link
    if (format == 'link') && link_url_changed? && !link_url.blank?
      # Queue up the embedly API call
      Entry.delay.refresh_link(self.id)
    end
  end

  def process_tweet
    if (format == 'tweet') && link_url_changed? && !link_url.blank?
      # Queue up the twitter API call
      Entry.delay.refresh_tweet(self.id)
    end
  end

  # Processes changes to the image from carrierwave direct key
  def self.do_process_image(entry_id)
    entry = Entry.find(entry_id)
    
    entry.processing_uploaded_image = false
    entry.image_processing_error = false
    entry.remote_uploaded_image_url = entry.direct_uploaded_image.direct_fog_url(with_path: true)
    
    if !entry.save
      UserMailer.entry_invalid_image(entry.id).deliver
      
      # Requery the entry from scratch in order to clear the carrierwave state
      entry = Entry.find(entry_id)
      entry.processing_uploaded_image = false
      entry.image_processing_error = true
      entry.save!
    end
  end

  # Processes changes to the file from carrierwave direct key
  def self.do_process_file(entry_id)
    entry = Entry.find(entry_id)
    
    entry.processing_uploaded_file = false
    entry.file_processing_error = false
    entry.remote_uploaded_file_url = entry.direct_uploaded_file.direct_fog_url(with_path: true)
    
    if !entry.save
      # Requery the entry from scratch in order to clear the carrierwave state
      entry = Entry.find(entry_id)
      entry.processing_uploaded_file = false
      entry.file_processing_error = true
      entry.save!
    end
  end

  # This method takes care of updating the log as needed.
  def update_log
    if (context != 'log_add_validation') && log_id && log
      # First increment the entry number counter
      log.next_entry_number += 1
      
      log.save
    end
  end

  def send_notifications
    # Note: The created_at condition is to filter out sample_data & migrations
    if created_at > (Time.now - 2.hours)
      if (type == 'validation') && (log.user_id != creator_id) && !log.user.email_inactive
        UserMailer.delay.log_validation_received(log.user_id, creator.id, log.badge.group_id, \
          log.badge_id, log.id, self.id) 
      end
    end
  end

  # Update the log if this was a validation (runs after destroy)
  def check_log_validation_counts
    if (type == 'validation') && (context != 'bulk_destroy')
      # Update the log validation counts
      if log_validated
        log.validation_count -= 1
      else
        log.rejection_count -= 1
      end
      
      # Then remove this item from the log validations cache and save
      log.validations_cache.delete creator_id.to_s
      log.save
    end
  end

  #=== ANALYTICS ===#

  def update_analytics
    if new_record?
      IntercomEventWorker.perform_async({
        'event_name' => (type == 'validation') ? 'validation-create' : 'post-create',
        'email' => creator.email,
        'created_at' => Time.now.to_i
      })
    end
  end

end