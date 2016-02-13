class Entry
  include Mongoid::Document
  include Mongoid::Timestamps
  include JSONFilter
  include StringTools

  # === CONSTANTS === #
  
  MAX_SUMMARY_LENGTH = 140
  TYPE_VALUES = ['post', 'validation']
  FORMAT_VALUES = ['text', 'link', 'image', 'tweet', 'code']
  JSON_FIELDS = [:log, :creator, :parent_tag, :entry_number, :summary, :type, :log_validated, 
    :body_sections, :tags, :tags_with_caps]
  
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
  field :format,                          type: String, default: 'text'
  field :log_validated,                   type: Boolean
  field :parent_tag,                      type: String

  field :body,                            type: String
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
  validates :link_url, format: { with: TWITTER_URL_REGEX, message: "must be a valid Twitter url" },\
    if: :tweet_is_required?

  # Which fields are accessible?
  attr_accessible :parent_tag, :summary, :format, :log_validated, :body, :link_url, \
    :code_format, :uploaded_image_key

  # === CALLBACKS === #

  before_validation :set_default_values, on: :create
  before_validation :update_image_key
  before_save :process_parent_tag_and_content_changes
  before_save :update_body_versions # DO store the first value since it comes from the user
  after_save :process_image
  after_create :update_log
  after_create :send_notifications
  after_destroy :check_log_validation_counts

  before_save :update_analytics
  
  # === ENTRY METHODS === #

  def to_param
    entry_number || _id
  end

  # Validation methods
  def summary_is_required?
    ['text', nil, 'link', 'code'].include? format
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
  
  def tweet_is_required?
    format == 'tweet'
  end
  

  # Returns the font awesome icon code for this tag's format (ex: "fa-camera")
  def format_icon
    case format
    when 'link'
      icon_text = 'fa-link'
    when 'tweet'
      icon_text = 'fa-twitter'
    when 'image'
      icon_text = 'fa-camera'
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

protected
  
  def set_default_values
    self.entry_number ||= log.next_entry_number if log
    self.format = tag.format if format.nil? && tag
  end

  # Sets tag relationship based on parent_tag string
  # This also does format-specific processing 
  #   (since this is the only callback that's sure of the format on a new entry)
  def process_parent_tag_and_content_changes
    if !parent_tag.blank? && parent_tag_changed? && !log.badge_id.nil?
      matched_tags = Tag.where(badge: log.badge_id, name: parent_tag.downcase)
      if matched_tags.count > 0
        self.tag = matched_tags.first
        self.format = tag.format
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
    
    # Now attempt to pull down the tweet body using the twitter API
    if (format == 'tweet') && link_url_changed? && !link_url.blank?
      begin
        tweet_id = extract_tweet_id(link_url)
        tweet = $twitter.status(tweet_id)
        self.summary = tweet.text

        # Now that we have the tweet, let's store some metadata
        self.link_metadata = {
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
          'tweet_user_utc_offset' => tweet.user.utc_offset,
        }
      rescue Exception => e
        # Nothing found so rather than throw an error we'll just set the summary to an error value.
        self.summary = "No tweet found! Please check the link and try again." 
      end
    elsif (format == 'link') && link_url_changed? && !link_url.blank?
      # Transform special links into other sorts of embeds
      self.body = transform_link link_url
    end

    if body_changed? || summary_changed? || link_url_changed?
      # Linkify summary and body (and split body into sections)
      summary_result = linkify_text(summary, log.badge.group, log.badge)
      self.linkified_summary = summary_result[:text] if summary_changed?
      body_result = linkify_text(body, log.badge.group, log.badge)
      self.body_sections = body_result[:text].split(SECTION_DIVIDER_REGEX) if body_changed?
      
      # The entry tags should be a concatenation of the summary and body tags
      self.tags = [body_result[:tags], summary_result[:tags]].flatten.uniq
      self.tags_with_caps = [body_result[:tags_with_caps], summary_result[:tags_with_caps]]\
        .flatten.uniq
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
    if uploaded_image_key && uploaded_image_key_changed?
      self.direct_uploaded_image.key = uploaded_image_key
      self.processing_uploaded_image = true
    end
  end

  def process_image
    if processing_uploaded_image
      Entry.delay(queue: 'high').do_process_image(id)
    end
  end

  # Processes changes to the image from carrierwave direct key
  def self.do_process_image(entry_id)
    entry = Entry.find(entry_id)
    entry.processing_uploaded_image = false
    entry.remote_uploaded_image_url = entry.direct_uploaded_image.direct_fog_url(with_path: true)
    entry.save!
  end

  # This method takes care of updating the log as needed.
  def update_log
    if log_id && log
      # First increment the entry number counter
      log.next_entry_number += 1
      
      # Then check if all of the requirements are complete.
      # If so we will automatically request validation as long as it hasn't been done before
      if (log.validation_status!='validated') && log.date_requested.nil? && log.date_withdrawn.nil?
        everything_complete = true
        log.requirements_complete.each do |tag, complete|
          everything_complete = everything_complete && complete
        end
        log.date_requested = Time.now if everything_complete
      end
      
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

  # Update the log if this was a validation
  def check_log_validation_counts
    if type == 'validation'
      if log_validated
        log.validation_count -= 1
      else
        log.rejection_count -= 1
      end
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