class Group
  include Mongoid::Document
  include Mongoid::Timestamps
  include JSONFilter
  include JSONTemplater

  # === CONSTANTS === #

  MAX_NAME_LENGTH = 50
  MAX_URL_LENGTH = 30
  MAX_DESCRIPTION_LENGTH = 140
  MAX_WELCOME_MESSAGE_LENGTH = 1000
  MAX_LOCATION_LENGTH = 100
  TYPE_VALUES = ['free', 'paid']
  COLOR_VALUES = ['red', 'pink', 'purple', 'deep-purple', 'indigo', 'blue', 'light-blue', 'cyan', 
    'teal', 'green', 'light-green', 'lime', 'yellow', 'amber', 'orange', 'deep-orange', 'brown', 
    'grey', 'blue-grey']
  JOINABILITY_VALUES = ['open', 'closed']
  VISIBILITY_VALUES = ['public', 'private']
  COPYABILITY_VALUES = ['public', 'members', 'admins']
  TAG_ASSIGNABILITY_VALUES = ['members', 'admins']
  TAG_CREATABILITY_VALUES = ['members', 'admins']
  TAG_VISIBILITY_VALUES = ['public', 'members', 'admins']
  WELCOME_BADGE_TAG_ALL_BADGES = '***ALL BADGES***'

  JSON_FIELDS = [:name, :location, :type, :member_count, :admin_count, :total_user_count]
  JSON_MOCK_FIELDS = { 'image_url' => :avatar_image_url, 'url' => :issuer_website,
    'badge_count' => :badge_count, 'slug' => :url_with_caps, 'full_url' => :group_url,
    'badges' => :filtered_badges_array }

  JSON_TEMPLATES = {
    list_item: [:id, :name, :url, :url_with_caps, :location, :type, :member_count, :admin_count, 
      :total_user_count, :avatar_image_url, :avatar_image_medium_url, :avatar_image_small_url,
      :badge_count, :full_url, :full_path],
    simple_list_item_with_tags: [:id, :name, :url, :url_with_caps, :tags_cache],
    link_info: [:id, :name, :full_url, :full_path, :avatar_image_url, 
      :avatar_image_medium_url, :avatar_image_small_url],
    api_v1: {
      everyone: [:id, { :url => :record_path }, :parent_path, :name, { :url => :slug }, { :url_with_caps => :slug_with_caps }, :location, :type, 
        :color, { :avatar_image_url => :image_url }, { :avatar_image_medium_url => :image_medium_url }, 
        { :avatar_image_small_url => :image_small_url }, :member_count, :admin_count, :total_user_count, :badge_count, 
        :full_url, { :full_path => :relative_url }, :current_user_permissions]
    }
  }

  PENDING_TRANSFER_FLAG = 'pending_transfer'
  PENDING_SUBSCRIPTION_FLAG = 'pending_subscription'

  BOUNCED_EMAIL_LOG_MAX_LENGTH = 100

  DEFAULT_GROUP_AVATAR_PATH = 'app/assets/images/default-group-avatar.png'
  DEFAULT_GROUP_AVATAR_FILE = 'default-group-avatar.png'
  DEFAULT_GROUP_AVATAR_REMOTE_URL = {
    nil => 'https://badgelist.s3.amazonaws.com/images/default-group-avatar.png',
    :medium => 'https://badgelist.s3.amazonaws.com/images/default-group-avatar-200.png',
    :small => 'https://badgelist.s3.amazonaws.com/images/default-group-avatar-50.png'
  }

  # === INSTANCE VARIABLES === #

  attr_accessor :context # Used to prevent certain callbacks from firing in certain contexts
  attr_accessor :current_user # Used to set current user context during API calls

  # === RELATIONSHIPS === #

  belongs_to :creator, inverse_of: :created_groups, class_name: 'User'
  belongs_to :owner, inverse_of: :owned_groups, class_name: 'User'
  has_and_belongs_to_many :admins, inverse_of: :admin_of, class_name: 'User'
  has_and_belongs_to_many :members, inverse_of: :member_of, class_name: 'User',
    after_add: :do_group_welcome
  has_many :badges, dependent: :restrict # You have to delete all the badges FIRST
  has_many :info_items, dependent: :destroy
  has_many :tags, dependent: :destroy, class_name: 'GroupTag'

  # === FIELDS & VALIDATIONS === #

  field :name,                            type: String
  field :url,                             type: String
  field :url_with_caps,                   type: String
  field :description,                     type: String
  field :location,                        type: String
  field :website,                         type: String
  field :type,                            type: String, default: 'free'
  field :color,                           type: String, default: 'light-blue'
  field :joinability,                     type: String, default: 'open'
  field :customer_code,                   type: String
  field :validation_threshold,            type: Integer, default: 1 # RETIRED FIELD
  field :invited_admins,                  type: Array, default: []
  field :invited_members,                 type: Array, default: []
  field :bounced_email_log,               type: Array, default: []
  field :flags,                           type: Array, default: []
  field :new_owner_username,              type: String
  field :previous_owner_id,               type: String
  
  field :image_url,                       type: String # RETIRED FIELD
  mount_uploader :direct_avatar,          S3DirectUploader
  mount_uploader :avatar,                 S3LogoUploader
  field :avatar_key,                      type: String
  field :processing_avatar,               type: Boolean
  
  field :member_visibility,               type: String, default: 'public'
  field :admin_visibility,                type: String, default: 'public'
  field :badge_copyability,               type: String, default: 'public'
  field :join_code,                       type: String
  field :tag_assignability,               type: String, default: 'members'
  field :tag_creatability,                type: String, default: 'members'
  field :tag_visibility,                  type: String, default: 'public'
  
  field :user_limit_override,             type: Integer # manually overrides user_limit value from subscription plan
  field :admin_limit_override,            type: Integer # manually overrides admin_limit value from subscription plan
  field :full_member_group_override,      type: Integer # manually overrides full_member_groups value from subscription plan
  field :limited_member_group_override,   type: Integer # manually overrides limited_member_groups value from subscription plan
  field :features,                        type: Array, default: [] # use feature methods to access
  field :feature_grant_file_uploads,      type: Boolean
  field :feature_grant_reporting,         type: Boolean
  field :feature_grant_bulk_tools,        type: Boolean
  field :feature_grant_integration,       type: Boolean
  field :feature_grant_hub,               type: Boolean
  field :feature_grant_leaderboards_weekly,   type: Boolean
  field :feature_grant_leaderboards_realtime, type: Boolean
  field :total_user_count,                type: Integer, default: 1
  field :admin_count,                     type: Integer, default: 1
  field :member_count,                    type: Integer, default: 0
  field :full_member_group_count,         type: Integer, default: 0
  field :limited_member_group_count,      type: Integer, default: 0
  field :active_user_count,               type: Integer # RETIRED
  field :monthly_active_users,            type: Hash # RETIRED

  field :lti_pending_keys,                type: Array, default: []
  field :lti_pending_key_details,         type: Hash, default: {}
  field :lti_context_ids,                 type: Array, default: []
  field :lti_context_details,             type: Hash, default: {}
  
  field :pricing_group,                   type: String, default: 'standard'
  field :subscription_plan,               type: String # values are defined in config.yml
  field :subscription_end_date,           type: Time
  field :stripe_payment_fail_date,        type: Time
  field :stripe_payment_retry_date,       type: Time
  field :stripe_subscription_card,        type: String
  field :stripe_subscription_id,          type: String
  field :stripe_subscription_details,     type: String
  field :stripe_subscription_status,      type: String
    # Possible Status Values = ['trialing', 'active', 'past_due', 'canceled', 'unpaid'] 
    #                          & 'new' & 'force-new', 'pending'
  field :revive_subscription,             type: Boolean
  field :stripe_push_pending,             type: Boolean, default: false # used to freeze webhook updates while pushing changes to stripe

  field :badges_cache,                    type: Hash, default: {} # key=badge_id, value=key_fields

  field :tags_cache,                      type: Hash, default: {} # key=gtag_id, value=key_fields
  field :top_user_tags_cache,             type: Array, default: []
  field :top_badge_tags_cache,            type: Array, default: []

  field :welcome_message,                 type: String
  field :welcome_badge_tag,               type: String

  validates :name, presence: true, length: { within: 5..MAX_NAME_LENGTH }
  validates :url_with_caps, presence: true, 
    uniqueness: { message: "The '%{value}' url is already taken."}, 
    length: { within: 2..MAX_URL_LENGTH }, format: { with: /\A[\w-]+\Z/,
    message: "can only contain letters, numbers, dashes and underscores" },
    exclusion: { in: APP_CONFIG['blocked_url_slugs'],
    message: "%{value} is a specially reserved url." }
  validates :url, presence: true, length: { within: 2..MAX_URL_LENGTH }, 
    uniqueness: { message: "The '%{value}' url is already taken."}, format: { with: /\A[\w-]+\Z/,
    message: "can only contain letters, numbers, dashes and underscores" },
    exclusion: { in: APP_CONFIG['blocked_url_slugs'],
    message: "%{value} is a specially reserved url." }
  validates :description, length: { maximum: MAX_DESCRIPTION_LENGTH }
  validates :welcome_message, length: { maximum: MAX_WELCOME_MESSAGE_LENGTH }
  validates :location, length: { maximum: MAX_LOCATION_LENGTH }
  validates :website, url: true
  validates :image_url, url: true
  validates :type, inclusion: { in: TYPE_VALUES, message: "%{value} is not a valid Group Type" }
  validates :color, inclusion: { in: COLOR_VALUES, message: "%{value} is not a valid color value" }
  validates :joinability, inclusion: { in: JOINABILITY_VALUES, 
    message: "%{value} is not a valid joinability type" }
  validates :member_visibility, inclusion: { in: VISIBILITY_VALUES, 
    message: "%{value} is not a valid type of visibility" }
  validates :admin_visibility, inclusion: { in: VISIBILITY_VALUES, 
    message: "%{value} is not a valid type of visibility" }
  validates :badge_copyability, inclusion: { in: COPYABILITY_VALUES, 
    message: "%{value} is not a valid type of copyability" }
  validates :tag_assignability, inclusion: { in: TAG_ASSIGNABILITY_VALUES, 
    message: "%{value} is not a valid type of assignability" }
  validates :tag_creatability, inclusion: { in: TAG_CREATABILITY_VALUES, 
    message: "%{value} is not a valid type of creatability" }
  validates :tag_visibility, inclusion: { in: TAG_VISIBILITY_VALUES, 
    message: "%{value} is not a valid type of visibility" }
  
  validate :new_owner_username_exists
  validate :subscription_fields_valid

  # === CALLBACKS === #

  before_validation :set_default_values, on: :create
  before_validation :update_avatar_key
  before_validation :update_validated_fields
  before_validation :update_caps_field
  after_validation :copy_errors
  before_create :add_creator_to_admins
  before_update :change_owner
  before_update :update_counts
  
  before_save :update_paid_defaults
  before_save :process_subscription_field_updates
  before_save :process_tags_cache_changes
  after_save :push_stripe_changes
  after_save :process_avatar
  after_update :update_child_badges
  after_update :push_stripe_metadata_changes
  after_destroy :cancel_subscription_on_destroy
  
  before_save :update_analytics

  # === GROUP MOCK FIELD METHODS === #
  # These are used to mock the presence of certain fields in the JSON output.

  def primary_email; (!creator.nil?) ? creator.email : nil; end
  def issuer_website; (website.blank?) ? "#{ENV['root_url']}/#{url}" : website; end

  def group_url
    "#{ENV['root_url'] || 'https://www.badgelist.com'}/#{url_with_caps}"
  end
  def full_url; group_url; end

  def full_path
    "/#{url_with_caps}"
  end

  # Only needed for compatibility with recordItem spec
  def parent_path
    nil
  end

  # Returns URL of the specified version of this group's avatar
  # Valid version values are nil (defaults to full size), :medium, :small
  def avatar_image_url(version = nil)
    avatar_url(version) || DEFAULT_GROUP_AVATAR_REMOTE_URL[version]
  end
  def avatar_image_medium_url; avatar_url(:medium); end
  def avatar_image_small_url; avatar_url(:small); end

  def badge_count; badges_cache.count; end
  def badge_urls_with_caps
    if badges_cache.blank?
      []
    else
      badges_cache.map{ |badge_id, badge_item| badge_item['url_with_caps'] }
    end
  end

  # Uses the current_user accessor.
  # Returns the badges cache hash with entries of only the badges which the current user can see.
  def filtered_badges_cache
    if badges_cache.blank?
      []
    else
      badges_cache.select do |badge_id, badge_item|
        (badge_item['visibility'] == 'public') || (                                                       \
          current_user.present? && (                                                                      \
            current_user.admin                                                                            \
            || has_admin?(current_user)                                                                   \
            || ((badge_item['visibility'] == 'private') && has_member?(current_user))                     \
            || ((badge_item['visibility'] == 'hidden') && current_user.learner_or_expert_of?(badge_id))   \
          )                                                                                               \
        )
      end
    end
  end

  # Uses the current_user accessor.
  # Returns the badges cache hash mapped into an array with entries of only the badges which the current user can see.
  def filtered_badges_array
    filtered_badges_cache.map{ |badge_id, badge_item| { 'id' => badge_id }.merge badge_item }
  end

  # Uses the current_user accessor.
  # Returns urls of badges the user can see.
  def filtered_badge_urls
    filtered_badges_cache.map{ |badge_id, badge_item| badge_item['url'] }
  end

  # Uses the current_user accessor.
  # Returns urls of badges the user can see.
  def filtered_badge_ids
    filtered_badges_cache.keys
  end

  # This is used by the API and requires that the current_user model attribute be set
  def current_user_permissions
    if current_user
      {
        can_see_record: true,
        is_member: has_member?(current_user),
        is_admin: has_admin?(current_user)
      }
    else
      {
        can_see_record: true,
        is_member: false,
        is_admin: false
      }
    end
  end

  def stripe_subscription_url
    if stripe_subscription_id.blank?
      nil
    else
      if ENV['stripe_livemode'] == 'true'
        "https://dashboard.stripe.com/subscriptions/#{stripe_subscription_id}"
      else
        "https://dashboard.stripe.com/test/subscriptions/#{stripe_subscription_id}"
      end
    end
  end

  # === GROUP METHODS === #

  # This will find by ObjectId OR by URL
  def self.find(input)
    group = nil

    if input.to_s.match /^[0-9a-fA-F]{24}$/
      group = super rescue nil
    end

    if group.nil?
      group = Group.find_by(url: input.to_s.downcase) rescue nil
    end

    group
  end

  # === LIMIT-FOCUSED INSTANCE METHODS === #

  def disabled?
    paid? && ( \
      ((stripe_subscription_status == 'canceled') && (Time.now >= subscription_end_date)) \
        || (stripe_subscription_status == 'unpaid')
    )
  end

  def user_limit
    if user_limit_override.present?
      user_limit_override
    elsif paid? && ALL_SUBSCRIPTION_PLANS[subscription_plan].present?
      ALL_SUBSCRIPTION_PLANS[subscription_plan]['users']
    else
      -1
    end
  end

  def can_add_members?(how_many = 1)
    free? || ((user_limit < 0) || ((member_count + how_many) <= user_limit))
  end

  # Returns hash = {
  #   color: 'default' or 'red'
  #   label: one_or_two_word_summary_of_current_status,
  #   summary: contents_of_detail_tooltip,
  #   requires_attention: true or false
  # }
  def member_limit_details
    if free? || user_limit.blank?
      { color: 'default', requires_attention: false, label: 'Unlimited', 
        summary: 'Free groups support unlimited members.' }
    elsif user_limit < 0
      { color: 'default', requires_attention: false, label: 'Unlimited', 
        summary: 'Your plan supports unlimited members.' }
    elsif member_count < user_limit
      { color: 'default', requires_attention: false, 
        label: "Using #{member_count}/#{user_limit}", 
        summary: "You're currently using #{member_count} out of #{user_limit} available " \
        + "member spots for your plan." }
    elsif member_count == user_limit
      { color: 'default', requires_attention: false, label: "None Remaining", 
        summary: "You are currently using all #{user_limit} of the available member spots for " \
        + "your plan. To get more members you'll need to upgrade to a larger plan." }
    else
      { color: 'red', requires_attention: true, label: "Over limit", 
        summary: "You are currently using more than the #{user_limit} member spots supported by " \
        + "your plan. To fix this you will need to either remove #{member_count - user_limit} " \
        + " members or upgrade to a larger plan as soon as possible." }
    end
  end

  def admin_limit
    if admin_limit_override.present?
      admin_limit_override
    elsif paid? && ALL_SUBSCRIPTION_PLANS[subscription_plan].present?
      ALL_SUBSCRIPTION_PLANS[subscription_plan]['admins']
    else
      -1
    end
  end

  def can_add_admins?(how_many = 1)
    free? || ((admin_limit < 0) || ((admin_count + how_many) <= admin_limit))
  end

  # Returns hash = {
  #   color: 'default' or 'red'
  #   label: one_or_two_word_summary_of_current_status,
  #   summary: contents_of_detail_tooltip,
  #   requires_attention: true or false
  # }
  def admin_limit_details
    if free? || admin_limit.blank?
      { color: 'default', requires_attention: false, label: 'Unlimited', 
        summary: 'Free groups support unlimited admins.' }
    elsif admin_limit < 0
      { color: 'default', requires_attention: false, label: 'Unlimited', 
        summary: 'Your plan supports unlimited admins.' }
    elsif admin_count < admin_limit
      { color: 'default', requires_attention: false, label: "Using #{admin_count}/#{admin_limit}", 
        summary: "You're currently using #{admin_count} out of #{admin_limit} available " \
        + "admin spots for your plan." }
    elsif admin_count == admin_limit
      if admin_limit == 1
        { color: 'default', requires_attention: false, label: "None Remaining", 
          summary: "Your subscription plan only includes 1 admin. " \
          + "To get more admins you'll need to upgrade to a larger plan." }
      else
        { color: 'default', requires_attention: false, label: "None Remaining", 
          summary: "You are currently using all #{admin_limit} of the available admin spots for " \
          + "your plan. Please contact support if you're interested in increasing your admin " \
          + "limit." }
      end
    else
      if admin_limit == 1
        { color: 'red', requires_attention: true, label: "Over limit", 
          summary: "Your subscription plan only supports 1 admin but you currently have " \
          + "#{admin_count}. " \
          + "To fix this you will need to either remove #{admin_count - admin_limit} admins or " \
          + "upgrade to a larger plan as soon as possible." }
      else
        { color: 'red', requires_attention: true, label: "Over limit", 
          summary: "You are currently using more than the #{admin_limit} admin spots supported " \
          + "by your plan. Please remove #{admin_count - admin_limit} admins as soon as possible."}
      end
    end
  end

  def full_member_group_limit
    if full_member_group_override.present?
      full_member_group_override
    elsif paid? && ALL_SUBSCRIPTION_PLANS[subscription_plan].present?
      ALL_SUBSCRIPTION_PLANS[subscription_plan]['full_member_groups']
    else
      -1
    end
  end

  def can_add_full_member_groups?(how_many = 1)
    has?(:hub) && ((full_member_group_limit < 0) || ((full_member_group_count + how_many) <= full_member_group_limit))
  end

  def limited_member_group_limit
    if limited_member_group_override.present?
      limited_member_group_override
    elsif paid? && ALL_SUBSCRIPTION_PLANS[subscription_plan].present?
      ALL_SUBSCRIPTION_PLANS[subscription_plan]['limited_member_groups']
    else
      -1
    end
  end

  def can_add_limited_member_groups?(how_many = 1)
    has?(:hub) && ((limited_member_group_limit < 0) || ((limited_member_group_count + how_many) <= limited_member_group_limit))
  end

  def can_add_member_groups?
    can_add_full_member_groups? || can_add_limited_member_groups?
  end

  # Returns hash = {
  #   color: 'default' or 'red'
  #   label: one_or_two_word_summary_of_current_status,
  #   summary: contents_of_detail_tooltip,
  #   requires_attention: true or false
  # }
  def full_member_group_limit_details
    if !has?(:hub) || free? || full_member_group_limit.blank?
      { color: 'default', requires_attention: false, label: 'None', 
        summary: 'This is not a hub group.' }
    elsif full_member_group_limit < 0
      { color: 'default', requires_attention: false, label: 'Unlimited', 
        summary: 'Your plan supports unlimited full hub member groups.' }
    elsif full_member_group_count < full_member_group_limit
      { color: 'default', requires_attention: false, label: "Using #{full_member_group_count}/#{full_member_group_limit}", 
        summary: "You're currently using #{full_member_group_count} out of #{full_member_group_limit} available " \
        + "full hub member groups for your plan." }
    elsif full_member_group_count == full_member_group_limit
      { color: 'default', requires_attention: false, label: "None Remaining", 
        summary: "You are currently using all #{full_member_group_limit} of the available full hub member groups for your plan. " \
        + "Please contact support if you're interested in increasing your limit." }
    else
      { color: 'red', requires_attention: true, label: "Over limit", 
        summary: "You are currently using more than the #{full_member_group_limit} full hub member groups supported by your plan. " \
        + "Please remove #{full_member_group_count - full_member_group_limit} of your full hub member groups as soon as possible."}
    end
  end

  # Returns hash = {
  #   color: 'default' or 'red'
  #   label: one_or_two_word_summary_of_current_status,
  #   summary: contents_of_detail_tooltip,
  #   requires_attention: true or false
  # }
  def limited_member_group_limit_details
    if !has?(:hub) || free? || limited_member_group_limit.blank?
      { color: 'default', requires_attention: false, label: 'None', 
        summary: 'This is not a hub group.' }
    elsif limited_member_group_limit < 0
      { color: 'default', requires_attention: false, label: 'Unlimited', 
        summary: 'Your plan supports unlimited limited hub member groups.' }
    elsif limited_member_group_count < limited_member_group_limit
      { color: 'default', requires_attention: false, label: "Using #{limited_member_group_count}/#{limited_member_group_limit}", 
        summary: "You're currently using #{limited_member_group_count} out of #{limited_member_group_limit} available " \
        + "limited hub member groups for your plan." }
    elsif limited_member_group_count == limited_member_group_limit
      { color: 'default', requires_attention: false, label: "None Remaining", 
        summary: "You are currently using all #{limited_member_group_limit} of the available limited hub member groups for your plan. " \
        + "Please contact support if you're interested in increasing your limit." }
    else
      { color: 'red', requires_attention: true, label: "Over limit", 
        summary: "You are currently using more than the #{limited_member_group_limit} limited hub member groups supported by your plan. " \
        + "Please remove #{limited_member_group_count - limited_member_group_limit} of your limited hub member groups as soon as possible."}
    end
  end

  # Returns whether or not the features array contains the specified 'feature' or :feature
  def has?(feature)
    return_value = features.present? && features.include?(feature.to_s)
    
    # Enable manual granting of features
    if (feature.to_s == 'reporting')
      return_value ||= (feature_grant_reporting == true)
    elsif (feature.to_s == 'file_uploads')
      return_value ||= (feature_grant_file_uploads == true)
    elsif (feature.to_s == 'bulk_tools')
      return_value ||= (feature_grant_bulk_tools == true)
    elsif (feature.to_s == 'integration')
      return_value ||= (feature_grant_integration == true)
    elsif (feature.to_s == 'hub')
      return_value ||= (feature_grant_hub == true)
    elsif (feature.to_s == 'leaderboards_weekly')
      return_value ||= (feature_grant_leaderboards_weekly == true)
    elsif (feature.to_s == 'leaderboards_realtime')
      return_value ||= (feature_grant_leaderboards_realtime == true)
    elsif (feature.to_s == 'privacy')
      return_value ||= paid?
    end

    return_value
  end

  # Returns an array of string values representing the keys of all features present on this group.
  # NOTE: Use this instead of accessing features directly (in order to include manual grants)
  def all_features
    return_list = features || []
    
    if feature_grant_file_uploads && !return_list.include?('file_uploads')
      return_list << 'file_uploads'
    end
    if feature_grant_reporting && !return_list.include?('reporting')
      return_list << 'reporting'
    end
    if feature_grant_bulk_tools && !return_list.include?('bulk_tools')
      return_list << 'bulk_tools'
    end
    if feature_grant_integration && !return_list.include?('integration')
      return_list << 'integration'
    end
    if feature_grant_hub && !return_list.include?('hub')
      return_list << 'hub'
    end
    if feature_grant_leaderboards_weekly && !return_list.include?('leaderboards_weekly')
      return_list << 'leaderboards_weekly'
    end
    if feature_grant_leaderboards_realtime && !return_list.include?('leaderboards_realtime')
      return_list << 'leaderboards_realtime'
    end
    if paid? && !return_list.include?('privacy')
      return_list << 'privacy'
    end

    return_list
  end

  # Returns true if this group has features either as part of a subscription *or* manually granted
  def has_features?
    all_features.present?
  end

  # This method will append the passed item to the bounced email log and automatically shorten
  # the log if it is over BOUNCED_EMAIL_LOG_MAX_LENGTH.
  def log_bounced_email(email, bounced_at, is_inactive)
    self.bounced_email_log << { email: email, bounced_at: bounced_at, is_inactive: is_inactive }
    self.bounced_email_log = bounced_email_log.last(BOUNCED_EMAIL_LOG_MAX_LENGTH)
  end

  # Returns the name of this subscription plan or just the id
  def subscription_plan_name
    if subscription_plan.blank?
      'No plan selected'
    elsif ALL_SUBSCRIPTION_PLANS[subscription_plan].blank?
      subscription_plan
    else
      ALL_SUBSCRIPTION_PLANS[subscription_plan]['name']
    end
  end

  def subscription_plan_cost
    if subscription_plan.blank?
      'Free'
    elsif ALL_SUBSCRIPTION_PLANS[subscription_plan].blank?
      'None'
    else
      plan_fields = ALL_SUBSCRIPTION_PLANS[subscription_plan]
      "$#{plan_fields['amount']/100} per #{plan_fields['interval']}"
    end
  end

  # Returns stripe_subscription_status as a readable string
  def subscription_status_string
    if paid?
      case stripe_subscription_status
      when 'new', 'force-new', 'pending'
        'Pending'
      when 'trialing'
        if subscription_end_date.present?
          'Trial'
        else
          'Pending'
        end
      when 'active'
        'Active'
      when 'past_due'
        'Past Due'
      when 'canceled'
        'Canceled'
      when 'unpaid'
        'Unpaid'
      else
        'None'
      end
    else
      'None'
    end
  end

  # Returns hash = {
  #   color: 'red', 'orange', 'blue' or 'green',
  #   summary: summary_of_current_status,
  #   icon: 'fa-check' (or the like),
  #   show_alert: true or false,
  #   alert_title: title_of_alert_if_shown,
  #   alert_body: body_of_alert_if_shown,
  # }
  def status_details_for_admins
    if free?
      { color: 'green', summary: 'Free group', icon: 'fa-check-circle', show_alert: false }
    else
      date_failed = stripe_payment_fail_date || Time.now
      date_retry = stripe_payment_retry_date || (Time.now + 3.days)

      case stripe_subscription_status
      when 'new', 'force-new', 'trialing', 'pending'
        if subscription_end_date.present?
          { color: 'orange', icon: 'fa-clock-o', show_alert: true,
            summary: "Trial ends on #{(subscription_end_date || 2.weeks.from_now).to_s(:short_date)}",
            alert_title: "Group is in trial period",
            alert_body: ("Your paid group trial ends on " \
                        + "#{(subscription_end_date || 2.weeks.from_now).to_s(:short_date)}. " \
                        + "Your card will be charged when the trial is complete. " \
                        + "If you have any questions, send us an email at " \
                        + "<a href='mailto:solutions@badgelist.com'>solutions@badgelist.com" \
                        + "</a>.").html_safe }
        else
          { color: 'green', icon: 'fa-clock-o', show_alert: false,
            alert_title: "Initial charge pending",
            summary: "Subscription has just been created and is active pending the success of " \
            + "the initial payment. Check back in the next few minutes to confirm successful payment." }
        end
      when 'past_due'
        { color: 'red', icon: 'fa-exclamation-circle', show_alert: true,
          summary: "Payment failed on #{date_failed.to_s(:short_date)}",
          alert_title: "There is a billing problem with the group",
          alert_body: "There was a problem renewing your subscription on " \
            + "#{date_failed.to_s(:short_date_time)}. Payment will be attempted again on " \
            + "#{date_retry.to_s(:short_date_time)}, please update your billing " \
            + "details before the next attempt to ensure your group's continued service." }
      when 'unpaid'
        { color: 'red', icon: 'fa-exclamation-triangle', show_alert: true,
          summary: "Subscription expired on #{subscription_end_date.to_s(:short_date)}",
          alert_title: "Group is inactive due to failed payments",
          alert_body: "There was a problem renewing your subscription after several attempts. " \
            + "The final payment attempt was made on #{date_failed.to_s(:short_date_time)}. "\
            + "Your group will remain inactive until you update your billing details or change " \
            + "the group type to free. You can also choose to cancel your subscription which " \
            + "will leave your group's contents online but prevent new content from being posted." }
      when 'canceled'
        if (Time.now < subscription_end_date)
          { color: 'orange', icon: 'fa-clock-o', show_alert: true,
            summary: "Grace period expires #{subscription_end_date.to_s(:short_date)}",
            alert_title: "Group is currently inactive",
            alert_body: "Your group's subscription is currently inactive but within the two week " \
              + "grace period. The grace period expires on " \
              + "#{subscription_end_date.to_s(:short_date)}, after that all group content will " \
              + "remain online, but no new content will be able to be posted. To reactivate the " \
              + "group at any time just select a plan and confirm your billing details." }
        else
          { color: 'blue', icon: 'fa-close', show_alert: true,
            summary: "Group is inactive", alert_title: "Group is currently inactive",
            alert_body: "Your group's subscription is currently inactive. All group content will " \
              + "remain online, but no new content can be posted. You can reactivate the group " \
              + "at any time by selecting a plan and confirming your billing details." }
        end
      else
        { color: 'green', icon: 'fa-check-circle', show_alert: false,
          alert_title: "Group is active",
          summary: "Subscription renews #{(subscription_end_date.present?) ? subscription_end_date.to_s(:short_date) : 'automatically'}" }
      end
    end
  end

  # Returns hash = {
  #   show_alert: true or false,
  #   color: 'red', 'orange', 'blue' or 'green',
  #   icon: 'fa-check' (or the like),
  #   alert_title: title_of_alert_if_shown,
  #   alert_body: body_of_alert_if_shown,
  # }
  def status_details_for_members
    if paid? && \
        ((stripe_subscription_status == 'canceled') && (Time.now >= subscription_end_date) \
          || (stripe_subscription_status == 'unpaid'))
      { color: 'blue', icon: 'fa-close', show_alert: true,
        alert_title: "This group is currently inactive",
        alert_body: "While the group is inactive all existing content will " \
          + "remain online, but no new content can be posted. " \
          + "Please contact the group admins with any questions." }
    else
      { show_alert: false }
    end
  end

  # === INSTANCE METHODS === #

  def to_param
    url_with_caps
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

  def free?
    type == 'free'
  end
  
  def paid?
    type == 'paid'
  end

  # Does this group have open membership?
  def open?
    joinability == 'open'
  end

  # Does this group have closed membership?
  def closed?
    joinability == 'closed'
  end

  def user_count
    admin_ids.count + member_ids.count
  end

  def badge_count
    badges_cache.count
  end
  
  def has_member?(user)
    member_ids.include?(user.id)
  end

  def has_admin?(user)
    admin_ids.include?(user.id)
  end

  def has_invited_member?(email)
    found_user = invited_members.detect { |u| u["email"] == email}
    found_user != nil
  end

  def has_invited_admin?(email)
    found_user = invited_admins.detect { |u| u["email"] == email}
    found_user != nil
  end

  # Returns URL of the group's logo (either from the image_url property or the Badge List default)
  def logo_url
    if image_url
      image_url
    elsif ENV['cdn_asset_host']
      "http://#{ENV['cdn_asset_host']}/assets/group-image-default.png"
    else
      "#{ENV['root_url']}/assets/group-image-default.png"
    end
  end

  # Returns user criteria for all members and admins
  # OPTIONS: 
  # Include without_tag to filter out anyone with that tag (pass the queried tag)
  # Or include without_tag_name to filter out anyone that tag (pass the tag name)
  def users(options = {})
    users_criteria = User.where(:id.in => (member_ids + admin_ids).uniq)
    
    # Add the without tag filter as needed
    if !options[:without_tag_name].blank?
      without_tag = tags.find_by(name: options[:without_tag_name].downcase) rescue nil
    else
      without_tag = options[:without_tag]
    end
    if without_tag
      users_criteria = users_criteria.where(:id.nin => without_tag.user_ids)
    end

    users_criteria
  end

  # Returns badge criteria
  # OPTIONS: 
  # Include without_tag to filter out badge with that tag (pass the queried tag)
  # Or include without_tag_name to filter out badge that tag (pass the tag name)
  def badges_query(options = {})
    badges_criteria = badges
    
    # Add the without tag filter as needed
    if !options[:without_tag_name].blank?
      without_tag = tags.find_by(name: options[:without_tag_name].downcase) rescue nil
    else
      without_tag = options[:without_tag]
    end
    if without_tag
      badges_criteria = badges_criteria.where(:id.nin => without_tag.badge_ids)
    end

    badges_criteria
  end

  # === GROUP TAGS === #

  # This does not use a query. It returns items from the top_user_tags_cache.
  # Specifically it returns only the tags which have been attached to at least one user.
  # Returns an empty array if there are no tags or if none have been attached to users.
  # Set [first] to an integer get the top [first] items
  def top_user_tags(first = nil)
    return_list = top_user_tags_cache.select{ |tag_item| tag_item['user_magnitude'] > 0 }
    if !first.blank?
      return_list = return_list.first(first)
    end
    return_list
  end

  # This does not use a query. It returns items from the top_badge_tags_cache.
  # Specifically it returns only the tags which have been attached to at least one badge.
  # Returns an empty array if there are no tags or if none have been attached to badges.
  # Set [first] to an integer get the top [first] items
  def top_badge_tags(first = nil)
    return_list = top_badge_tags_cache.select{ |tag_item| tag_item['badge_magnitude'] > 0 }
    if !first.blank?
      return_list = return_list.first(first)
    end
    return_list
  end

  # Returns a group tag criteria selecting only tags which have been attached to users.
  # Default sort is by descending magnitude then by ascending name.
  # OPTIONS:
  # - unsorted: Set this to true to leave off the sort parameters
  def user_tags(options = {})
    return_criteria = tags.where(:user_count.gt => 0)
    unless options[:unsorted]
      return_criteria = return_criteria.order_by('user_magnitude desc, name asc')
    end
    return_criteria
  end

  # Returns a group tag criteria selecting only tags which have been attached to badges.
  # Default sort is by descending magnitude then by ascending name.
  # OPTIONS:
  # - unsorted: Set this to true to leave off the sort parameters
  def badge_tags(options = {})
    return_criteria = tags.where(:badge_count.gt => 0)
    unless options[:unsorted]
      return_criteria = return_criteria.order_by('badge_magnitude desc, name asc')
    end
    return_criteria
  end

  # === GROUP ACTIONS === #

  # This updates or deletes the cached copy of the specified badge in the badges_cache
  # If the specified badge does not exist in the cache already then it will be added
  # If is_deleted is true then the specified badge will be deleted if present
  def update_badge_cache(badge_json_clone, is_deleted = false)
    badge_id = badge_json_clone['_id'].to_s
    
    if is_deleted
      self.badges_cache.delete badge_id
    else
      self.badges_cache[badge_id] = {
        'name' => badge_json_clone['name'],
        'editability' => badge_json_clone['editability'],
        'awardability' => badge_json_clone['awardability'],
        'visibility' => badge_json_clone['visibility'],
        'summary' => badge_json_clone['summary'],
        'url' => badge_json_clone['url'],
        'url_with_caps' => badge_json_clone['url_with_caps'],
        'image_url' => badge_json_clone['image_url'],
        'image_medium_url' => badge_json_clone['image_medium_url'],
        'image_small_url' => badge_json_clone['image_small_url']
      }
    end
  end

  # Adds or updates the specified tag in tags_cache w/o querying the tag
  def update_tags_cache(tag_json)
    self.tags_cache[tag_json['_id'].to_s] = tag_json
  end
  
  # Same as above but for async calls
  def self.update_tags_cache(group_id, tag_json)
    group = Group.find(group_id)
    group.update_tags_cache tag_json
    group.timeless.save
  end

  # Removes the specified tag_id from tags_cache w/o querying the tag
  def remove_tag_from_cache(tag_id)
    self.tags_cache.delete tag_id.to_s
  end

  # Same as above but for async calls
  def self.remove_tag_from_cache(group_id, tag_id)
    group = Group.find(group_id)
    group.remove_tag_from_cache tag_id
    group.timeless.save
  end

  # Queries for all group_tags related to any of the specified user_ids and then removes the users
  # from each tag, one at a time.
  # NOTE: This should be run asynch because it is potentially resource intensive
  def self.remove_users_from_all_tags(group_id, user_ids, current_user_id)
    group = Group.find(group_id)
    related_group_tags = group.tags.where(:user_ids.in => user_ids)

    related_group_tags.each do |group_tag|
      group_tag.remove_users(user_ids, current_user_id) # runs synchronously
    end
  end

  # This will add a validation item to the invited_member or invited_admin list for this email
  # If the user has not yet been invited to the group they will be added as a member (an exception is raised if group is full).
  # If an existing validation for this email and badge_url already exists for this current_user_id, it will be overwritten
  # Returns the created/updated validation_item hash.
  def add_invited_user_validation(current_user_id, email, badge_url, summary, body, preserve_body_html = false)
    # Attempt to find an existing invitation for them and create a new one if needed
    invited_user_item = invited_admins.detect{ |item| item['email'] == email }
    invited_user_item ||= invited_members.detect{ |item| item['email'] == email }
    if invited_user_item.nil?
      if can_add_members?
        invited_user_item = { 
          'email' => email, 
          'invite_date' => Time.now, 
          'validations' => [] 
        }
        self.invited_members << invited_user_item
      else
        raise StandardError.new('Group is full')
      end
    end

    # Now attempt to find an existing validation for this combination of current_user_id and badge_url. Create blank one if not found.
    invited_user_item['validations'] = [] if invited_user_item['validations'].nil?
    validation_item = invited_user_item['validations'].detect do |item|
      (item['user'].to_s == current_user_id.to_s) && (item['badge'] == badge_url)
    end
    if validation_item.nil?
      validation_item = {}
      invited_user_item['validations'] << validation_item
    end

    # Finally we can set (or overwrite) the fields of the validation
    validation_item['user'] = current_user_id.to_s
    validation_item['badge'] = badge_url
    validation_item['summary'] = summary
    validation_item['body'] = body
    validation_item['preserve_body_html'] = preserve_body_html

    # Return the item
    validation_item
  end

  # === CLONING METHODS === #

  # Returns an array of badge json clones for the badges with the specified URLs
  # Pass nil to get ALL badge json clones
  def get_badge_json_clones(badge_urls = nil)
    if badge_urls.blank?
      badges.map{ |badge| badge.json_clone }
    else
      badges.where(:url.in => badge_urls).map{ |badge| badge.json_clone }
    end
  end

  # Pass an array of badge json clones and a user to specify as the badge creator
  # Returns the same array back with an added 'result' key with the following sub-keys:
  #  'success' => true or false
  #  'error_message' => string (if !success)
  #  'json_clone' => the json clone of the newly created badge (if success)
  def create_badges_from_json_clones(creator, badge_json_clones)
    return_list = []

    badge_json_clones.each do |badge_json_clone|
      result = Badge.create_from_json_clone(creator, self, badge_json_clone, 'group_async')
      return_list << result
      update_badge_cache result['json_clone'] if result['success']
    end

    group.timeless.save! if group.changed?
    return_list
  end

  # Copies the badges with the specified urls from this group to destination group
  # If async is set to true then the method will return the id of a poller
  # NOTE: Passing nil for [badge_urls] will copy ALL badges
  def copy_badges_to_group(creator_id, badge_urls, to_group_id, async = false)
    if async
      to_group = Group.find(to_group_id) rescue nil
      to_group_name = (to_group) ? to_group.name : 'Unknown Group'
      poller = Poller.new
      poller.waiting_message = "Copying badges from '#{name}' to '#{to_group_name}'..."
      poller.progress = 1 # this will put the poller into 'progress mode'
      poller.data = { from_group_id: self.id.to_s, to_group_id: to_group_id.to_s, 
        creator_id: creator_id.to_s, badge_urls: badge_urls }
      poller.save
      Group.delay(queue: 'high').do_copy_badges_to_group(creator_id, self.id, badge_urls, 
        to_group_id, poller.id)
      poller.id
    else
      Group.do_copy_badges_to_group(creator_id, nil, badge_urls, to_group_id, nil, from_group: self)
    end
  end

  # Pass :from_group, :to_group or :creator into options to skip queries
  def self.do_copy_badges_to_group(creator_id, from_group_id, badge_urls, to_group_id, 
      poller_id=nil, options = {})
    begin
      # First query for the core records
      poller = Poller.find(poller_id) rescue nil
      creator = options[:creator] || User.find(creator_id)
      from_group = options[:from_group] || Group.find(from_group_id)
      to_group = options[:to_group] || Group.find(to_group_id)

      # Now get the json and initialize our tracking variables
      badge_json_clones = from_group.get_badge_json_clones(badge_urls).select do |badge_item|
        creator.admin || creator.admin_of?(from_group)       \
          || (badge_item['visibility'] == 'public')           \
          || creator.learner_or_expert_of?(badge_item['_id'])  \
          || (creator.member_of?(from_group) && (badge_item['visibility'] == 'private'))
      end
      badge_count = badge_json_clones.count
      progress_count, success_count, error_count = 0, 0, 0
      last_error_message = nil
      
      # Loop through the badges and copy them, updating the poller progress as we go
      badge_json_clones.each do |badge_json_clone|
        result = Badge.create_from_json_clone(creator, to_group, badge_json_clone, 'group_async')
        
        progress_count += 1
        if result['success']
          to_group.update_badge_cache result['json_clone']
          success_count += 1
        else
          error_count += 1
          last_error_message = result['error_message']
        end

        if poller
          poller.progress = progress_count * 100 / badge_count
          poller.save
        end
      end
        
      # Then save badge cache if needed (Note: we need to refresh the model but save the json)
      if to_group.changed?
        badges_cache_backup = to_group.badges_cache
        to_group.reload
        to_group.badges_cache = badges_cache_backup
        to_group.timeless.save!
      end

      if poller
        if success_count > 0
          poller.status = 'successful'
          poller.message = "#{success_count} badges successfully copied " \
            + "from '#{from_group.name}'."
          if error_count > 0
            poller.message << " (#{error_count} badges could not be copied due to errors.)"
          end
          poller.redirect_to = "/#{to_group.url_with_caps}"
        else
          poller.status = 'failed'
          poller.message = 'None of the badges could be copied to your group due to errors. ' \
            + "(Last Error Message: #{last_error_message})"
        end
        poller.save
      end
    rescue Exception => e
      if poller
        poller.status = 'failed'
        poller.message = 'An error occurred while trying to copy the badges, ' \
          + "please try again. (Error message: #{e})"
        poller.save
      else
        throw e
      end
    end
  end

  # === ASYNC CLASS METHODS === #

  # Update the cached badge details on all related badges
  def self.update_child_badge_fields(group_id)
    group = Group.find(group_id)
    group.badges.each do |badge|
      badge.update_group_fields_from group
      badge.timeless.save
    end

    return group.badges.count
  end

  # Adds all of the user to the group unless they already exist as members or admins
  def bulk_add_members(user_ids, async = false)
    if async
      Group.delay(queue: 'high').bulk_add_members(self.id, user_ids)
    else
      Group.bulk_add_members(nil, user_ids, self)
    end
  end
  
  # Adds all of the user to the group unless they already exist as members or admins
  # Provide group to skip the query
  def self.bulk_add_members(group_id, user_ids, group = nil)
    group = Group.find(group_id) unless group

    User.where(:id.in => user_ids).each do |user|
      if !group.has_member?(user) && !group.has_admin?(user)
        group.members << user
      end
    end

    group.save if group.changed?
  end

  # === LTI (CLASS & INSTANCE) METHODS === #

  # Generates a new lti key pair and adds it to the lti_pending_keys/details
  # Returns hash with following keys: name, consumer_key, secret_key
  # NOTE: Does not commit the save
  def add_lti_key_pair(creator_user, name)
    consumer_key, secret_key = SecureRandom.hex(30), SecureRandom.hex(30)

    self.lti_pending_keys << consumer_key
    self.lti_pending_key_details[consumer_key] = {
      'creator_user_id' => creator_user.id.to_s,
      'name' => name,
      'secret_key' => secret_key
    }

    { name: name, consumer_key: consumer_key, secret_key: secret_key }
  end

  # Removes the specified key pair
  # Returns nil if not found else returns hash with following keys: name, consumer_key, secret_key
  # NOTE: Does not commit the save
  def remove_lti_key_pair(consumer_key)
    return_value = nil
    
    if lti_pending_keys.include?(consumer_key) && lti_pending_key_details.has_key?(consumer_key)
      return_value = { 
        name: lti_pending_key_details[consumer_key]['name'], 
        consumer_key: consumer_key,
        secret_key: lti_pending_key_details[consumer_key]['secret_key']
      }

      self.lti_pending_keys.delete consumer_key
      self.lti_pending_key_details.delete consumer_key
    end

    return_value
  end

  # Updates the navigation keys of the specified context id
  # Returns hash with following keys: context_id, name, navigate_to, navigate_to_id
  # NOTE: Does not commit the save
  def update_lti_context_details(context_id, navigate_to, navigate_to_id)
    return_value = nil

    if lti_context_ids.include?(context_id) && lti_context_details.has_key?(context_id)
      self.lti_context_details[context_id]['navigate_to'] = navigate_to
      self.lti_context_details[context_id]['navigate_to_id'] = navigate_to_id

      return_value = {
        context_id: context_id,
        name: lti_context_details[context_id]['name'],
        navigate_to: navigate_to,
        navigate_to_id: navigate_to_id
      }
    end

    return_value
  end

  # Removes the specified context id and details
  # Returns nil if not found else returns hash with following keys: name, context_id
  # NOTE: Does not commit the save
  def remove_lti_context(context_id)
    return_value = nil
    
    if lti_context_ids.include?(context_id) && lti_context_details.has_key?(context_id)
      return_value = { 
        name: lti_context_details[context_id]['name'], 
        context_id: context_id
      }

      self.lti_context_ids.delete context_id
      self.lti_context_details.delete context_id
    end

    return_value
  end

  # Call this method to check whether LTI launch params are valid and match a group and if so what
  # the current status of the LTI configuration is for the group.
  #
  # RETURNS a hash with following keys:
  # - group: This is the queried group object (if a matching group is found)
  # - status: ready (LTI is configured and active), pending (LTI key needs to be registered), 
  #           inactive (Expired group subscription), invalid (bad signature, no match, etc)
  # - error_message: User-safe error message (if inactive or invalid)
  # - lti_pending_key_details: Returned if status = 'pending', adds the consumer_key key
  # - lti_context_details: Returned if status = 'active', adds the context_id key
  def self.get_lti_status(launch_params)
    consumer_key = launch_params['oauth_consumer_key']
    context_id = launch_params['context_id'].to_s.parameterize
    oauth_signature = launch_params['oauth_signature']

    # First attempt to find the group (look for the pending key first since it's more unique)
    # NOTE: If the context id is a dupe that will get caught when they try to register it
    group = Group.where(:lti_pending_keys.in => [consumer_key]).first
    consumer_key_match = !group.nil?
    group = Group.where(:lti_context_ids.in => [context_id]).first if !consumer_key_match

    if group
      if consumer_key_match
        # The request is valid and we've got a match but we still need to register the context id
        lti_pending_key_details = group.lti_pending_key_details[consumer_key]\
          .merge({ 'consumer_key' => consumer_key })
        status = 'pending'
      else
        # The LTI integration is at least properly configured, but there are more things to check
        lti_context_details = group.lti_context_details[context_id]\
          .merge({ 'context_id' => context_id })

        if group.has?(:integration)
          if group.disabled?
            # The integration feature is not enabled
            status = 'inactive'
            error_message = 'The LTI integration is properly configured, but the linked ' \
              + 'Badge List group has an expired subscription. Please contact Badge List support.'
          else
            # We're good to go!
            status = 'ready'
          end
        else
          # The integration feature is not enabled
          status = 'inactive'
          error_message = 'The LTI integration is properly configured, but the linked ' \
            + 'Badge List group no longer has the integration feature. ' \
            + 'Please contact Badge List support.'
        end
      end
    else
      # There's no match whatsoever
      status = 'invalid'
      error_message = 'No matching Badge List group found. The LTI integration might need to be ' \
        + 'reconfigured. Please contact your site administrator.'
    end

    # Return the hash
    { group: group, status: status, error_message: error_message, 
      lti_pending_key_details: lti_pending_key_details, lti_context_details: lti_context_details }
  end

  # Call this method to upgrade a pending lti key to a registered context id.
  # This method checks for the following error states: No matching key on group, context_id has 
  # already been assigned to another group.
  # NOTE: Does not commit the save
  # TO SEND NOTIFICATION EMAIL TO ADMINS use Group.send_new_lti_notifications()
  #
  # IF SUCCESSFUL: Returns the created context details hash (with a context_id key added).
  # IF UNSUCCESSFUL: Raises a StandardError.
  def register_pending_lti_key(launch_params)
    consumer_key = launch_params['oauth_consumer_key']
    context_id = launch_params['context_id'].to_s.parameterize
    context_name = launch_params['context_title'] || launch_params['context_label']

    if lti_pending_keys.include?(consumer_key) && lti_pending_key_details.has_key?(consumer_key)
      already_linked_group = Group.where(:lti_context_ids.in => [context_id]).first

      if already_linked_group.nil?
        self.lti_context_ids << context_id
        self.lti_context_details[context_id] = {
          name: context_name,
          consumer_key: consumer_key,
          secret_key: lti_pending_key_details[consumer_key]['secret_key'],
          creator_user_id: lti_pending_key_details[consumer_key]['creator_user_id'],
          navigate_to: 'group',
          navigate_to_id: nil,
          initial_launch_params: launch_params
        }
        self.lti_pending_keys.delete consumer_key
        self.lti_pending_key_details.delete consumer_key

        # Return context details, but merge in the context id
        return lti_context_details[context_id].merge({ context_id: context_id })
      else
        raise StandardError.new('This LTI course has already been linked with another Badge List '\
          + "group (#{already_linked_group.name}). The same LTI course cannot be linked to " \
          + 'multiple Badge List groups.')
      end
    else
      raise StandardError.new('The provided key does not match any pending keys on this group.')
    end
  end

  # This method sends the new lti integration email notification to all of the group admins
  def self.send_new_lti_notifications(group_id, context_id)
    group = Group.find(group_id)

    group.admins.each do |user|
      if !user.email_inactive
        UserMailer.group_new_lti_integration(user.id, group_id, 
          group.lti_context_details[context_id]).deliver
      end
    end
  end

  # === STRIPE RELATED METHODS === #

  # This method will clear the limit override fields (useful when changing subscription plans)
  def clear_subscription_limit_overrides
    self.user_limit_override = nil
    self.admin_limit_override = nil
    self.full_member_group_override = nil
    self.limited_member_group_override = nil
  end

  # This method will refresh the features field from the ALL_SUBSCRIPTION_PLANS configuration 
  def refresh_subscription_features
    if !subscription_plan.blank? && ALL_SUBSCRIPTION_PLANS.has_key?(subscription_plan)
      self.features = ALL_SUBSCRIPTION_PLANS[subscription_plan]['features']
    end
  end

  # Use this to generate the hash which gets set as the metadata property of the group's stripe subscription
  # NOTE: If adding new metadata to this method, be sure to also update stripe_subscription_metadata_changed? below.
  def stripe_subscription_metadata
    {
      description: "#{name} (#{url})",
      group_id: id.to_s,
      group_url: url,
      group_name: name,
      group_website: website
    }
  end

  # Use this to see if any of the fields which contribute to the stripe_subscription_metadata have changed
  def stripe_subscription_metadata_changed?
    name_changed? || url_changed? || website_changed?
  end

  # This pushes a refreshed copy of the stripe_subscription_metadata to stripe (it does not touch any other aspects of the subscription)
  def self.push_metadata_to_stripe(group_id)
    begin
      group = Group.find(group_id)

      if group.stripe_subscription_id.present?
        subscription = Stripe::Subscription.retrieve(group.stripe_subscription_id)
        subscription.metadata = group.stripe_subscription_metadata
        subscription.save
      end
    rescue Exception => e
      if group
        # Log this error
        group.info_items.new(
          type: 'stripe-error',
          name: 'Problem Pushing Metadata to Stripe (Group.push_metadata_to_stripe)',
          data: { error: e.to_s }
        ).save
      else
        # No group so just throw the error
        throw e
      end
    end
  end

  # This pushes local changes to the subscription out to stripe so that stripe matches the local settings
  # This method will update the existing subscription if present or it will create a new subscription.
  # If set `throw_errors` is false then errors are logged as a 'stripe-error' InfoItem, otherwise they are thrown.
  def self.push_to_stripe(group_id, throw_errors = false)
    begin
      group = Group.find(group_id)

      # First we need to record that we are working on the subscription (so any incoming stripe webhooks will be ignored until we're done)
      group.stripe_push_pending = true
      group.save

      # Get the customer from stripe and set the customer's default source to be source specified on the group
      customer = Stripe::Customer.retrieve(group.owner.stripe_customer_id)
      confirmed_source = customer.sources.data.find{ |s| s.id == group.stripe_subscription_card }
      if confirmed_source.blank?
        group.stripe_subscription_card = customer.default_source
      elsif customer.default_source != confirmed_source.id
        customer.default_source = confirmed_source.id
        customer.save

        group.owner.stripe_default_source = confirmed_source.id
        group.owner.save
      end

      # If there is already a subscription id then we try to retrieve it from the stripe list on the customer
      if group.stripe_subscription_id.present?
        subscription = customer.subscriptions.data.find{ |s| s.id == group.stripe_subscription_id }

        if subscription.blank?
          # Either the id is corrupted (and we can safely discard it) or the plan is canceled (and we can safely discard it) 
          # or it corresponds to an active subscription on another customer (and discarding is bad)
          # Since this is a weird edge case that might never happen, for now we will record an info item and move on.
          group.info_items.new(
            type: 'stripe-error',
            name: 'Stripe Subscription Id Not Found (Group.push_to_stripe)',
            data: { group_id: group_id.to_s, group_url: group.url, group_name: group.name, 
              stripe_subscription_id: group.stripe_subscription_id, stripe_customer_id: customer.id }
          ).save

          # With that done, we can clear the invalid id
          group.stripe_subscription_id = nil
        end
      end

      # Now we either create a new subscription or update the existing one
      if subscription.blank?
        subscription = customer.subscriptions.create(
          items: [
            { plan: group.subscription_plan }
          ],
          metadata: group.stripe_subscription_metadata
        )
        
        intercom_event_name = 'stripe-subscription-create'
        info_item_event_type = 'created'
      else
        if subscription.plan.id != group.subscription_plan
          item_id = subscription.items.data[0].id
          subscription.items = [
            { id: item_id, plan: group.subscription_plan }
          ]
          subscription.prorate = true
          subscription.save
          
          intercom_event_name = 'stripe-subscription-update'
          info_item_event_type = 'changed'
        else
          intercom_event_name = 'stripe-subscription-card-change'
          info_item_event_type = nil # this won't create an info item
        end
      end
      
      group.stripe_subscription_id = subscription.id
      group.stripe_subscription_status = subscription.status
      group.stripe_subscription_details = subscription.to_hash
      group.subscription_end_date = subscription.current_period_end
      group.stripe_push_pending = false
      group.save

      # Track an info item (which can potentially be user-facing)
      if info_item_event_type.present?
        group.info_items.new(
          type: "group-subscription-#{info_item_event_type}",
          name: "Group Subscription was Successfully #{info_item_event_type.capitalize}",
          data: { stripe_subscription_id: group.stripe_subscription_id, subscription_plan: group.subscription_plan,
            owner_id: group.owner_id.to_s }
        ).save
      end

      # Then log an event in intercom
      IntercomEventWorker.perform_async({
        'event_name' => intercom_event_name,
        'email' => group.owner.email,
        'created_at' => Time.now.to_i,
        'metadata' => {
          'group_id' => group.id.to_s,
          'group_name' => group.name,
          'group_url' => group.group_url,
          'plan' => group.subscription_plan
        }
      })
    rescue Exception => e
      # Clear the push pending flag
      if group.stripe_push_pending
        group.stripe_push_pending = false
        group.save
      end

      if throw_errors
        throw e
      else
        # Log this error
        group.info_items.new(
          type: 'stripe-error',
          name: 'Problem Pushing to Stripe (Group.push_to_stripe)',
          data: { group_id: group_id.to_s, error: e.to_s }
        ).save
      end
    end
  end

  # Calls out to stripe to refresh the subscription status (Called from the stripe webhook)
  # If the stripe_push_pending boolean is true on the group, this method will only log an info item but will not do anything.
  #
  # Accepts the following options hash members:
  # - payment_fail_date: This will optionally cause the payment_fail_date to be updated
  # - payment_retry_date: This will optionally cause the payment_retry_date to be updated
  # - info_item_data: This will optionally result in the insertion of an info item 
  #     with type = "stripe-event" and name = "Invoice Payment"
  # - throw_errors: Set this to true to throw errors instead of logging them
  # - send_payment_failure_email: Set this to true to send a payment failure notification email to the group owner
  def self.pull_from_stripe(stripe_subscription_id, options = {})
    begin
      group = Group.find_by(stripe_subscription_id: stripe_subscription_id)
      group.context = 'stripe'

      if options[:info_item_data]
        # Create a user-facing info_item
        group.info_items.new(
          type: 'stripe-event', 
          name: 'Invoice Payment',
          data: options[:info_item_data], 
          user: group.owner
        ).save
      end

      if group.stripe_push_pending
        # This is a webhook event coming in while Group.push_to_stripe is running, so we ignore it
        group.info_items.new(
          type: 'stripe-event-ignored', 
          name: 'Ignored Stripe Event (Group.pull_from_stripe)',
          data: options
        ).save
      else
        begin
          # Retrieve the subscription 
          # Note: It's possible that somehow the customer doesn't match, not currently doing anything special if so.
          subscription = Stripe::Subscription.retrieve(group.stripe_subscription_id)

          # Determine whether we are going to log an info item
          if subscription.plan.id != group.subscription_plan
            info_item_event_type = 'changed'
          end

          group.subscription_plan = subscription.plan.id
          group.stripe_subscription_status = subscription.status
          group.stripe_subscription_details = subscription.to_hash
          group.subscription_end_date = subscription.current_period_end
          group.stripe_payment_fail_date = options[:payment_fail_date]
          group.stripe_payment_retry_date = options[:payment_retry_date]
          group.save
          
          # Track an info item if needed (which can potentially be user-facing)
          if info_item_event_type.present?
            group.info_items.new(
              type: "group-subscription-#{info_item_event_type}",
              name: "Group Subscription was Successfully #{info_item_event_type.capitalize}",
              data: { stripe_subscription_id: group.stripe_subscription_id, subscription_plan: group.subscription_plan,
                owner_id: group.owner_id.to_s }
            ).save
          end

          if options[:send_payment_failure_email]
            GroupMailer.delay(retry: 5, queue: 'low').payment_failure(group.id)
          end
        rescue Exception => e
          if subscription
            # There was an unanticipated error, throw it
            throw e
          else
            # The subscription couldn't be found, log the edge case (not sure how this would happen but it's important if it does)
            group.info_items.new(
              type: 'stripe-error', 
              name: 'Stripe Webhook Error - Subscription Not Found (Group.pull_from_stripe)',
              data: {
                stripe_subscription_id: group.stripe_subscription_id,
                options: options
              }
            ).save
          end
        end
      end
    rescue Exception => e
      if options[:throw_errors]
        throw e
      else
        # Log this error
        item = InfoItem.new
        item.type = 'stripe-error'
        item.name = 'Stripe Webhook Error (Group.pull_from_stripe)'
        item.data = { stripe_subscription_id: stripe_subscription_id, options: options, e: e.to_s }
        item.save
      end
    end
  end

  # Called from the stripe webhook. This method verifies that the stripe_subscription_id can be found on a group in the database.
  # If so, then it does nothing (which allows the invoice to be paid). If not, then it calls out to stripe to close the invoice 
  # without payment. Either way an InfoItem is recorded.
  # This is intended to prevent erroneous charges from inactive / duplicate subscriptions.
  # NOTE: Invoice validation is only enabled if the 'stripe_enable_invoice_validation' environment variable is set to the string 'true'.
  #   It is best to leave the validation disabled in staging / development unless you are actively testing it (otherwise the various dev 
  #   environments will cancel eachother's charges).
  def self.validate_stripe_invoice(stripe_invoice_id, stripe_subscription_id)
    if ENV['stripe_enable_invoice_validation'] != 'true'
      InfoItem.new(
        type: 'stripe-invoice-validation-skipped', 
        name: 'Skipped Validation of Invoice (Group.validate_stripe_invoice)',
        data: { stripe_invoice_id: stripe_invoice_id, stripe_subscription_id: stripe_subscription_id }
      ).save
    else
      group = Group.find_by(stripe_subscription_id: stripe_subscription_id) rescue nil

      if group.present?
        group.info_items.new(
          type: 'stripe-invoice-validated', 
          name: 'Verified Existence of Active Subscription (Group.validate_stripe_invoice)',
          data: { stripe_invoice_id: stripe_invoice_id, stripe_subscription_id: stripe_subscription_id }
        ).save
      else
        # First close the invoice in stripe (this will prevent the customer from getting charged)
        invoice_closing_error = nil
        begin
          invoice = Stripe::Invoice.retrieve(stripe_invoice_id)
          invoice.closed = true
          invoice.save
        rescue Exception => e
          invoice_closing_error = e
        end

        # Then log the error item
        item = InfoItem.new(
          type: 'stripe-invoice-canceled', 
          name: 'Could Not Verify Existence of Active Subscription (Group.validate_stripe_invoice)',
          data: {
            stripe_invoice_id: stripe_invoice_id,
            stripe_subscription_id: stripe_subscription_id,
            invoice_closed_successfully: invoice_closing_error.nil?,
            invoice_closing_error: ((invoice_closing_error.nil?) ? nil : invoice_closing_error.to_s)
          }
        )
        item.save

        # Then send an email to Badge List admins (since this subscription needs to be reviewed and potentially canceled in stripe)
        if invoice_closing_error.nil?
          email_subject = "Invalid Stripe Payment Prevented - #{stripe_invoice_id}"
          email_title = 'A pending invoice was automatically closed, please review Stripe for potential error'
          email_body = 'The invoice validation process prevented a payment from going through. This happened because the subscription id ' \
            + 'did not match any groups in the database. This might be an indication of an erroneous subscription which needs to be ' \
            + 'manually canceled in Stripe. Please click the link below to investigate.'
          color = 'blue_grey'
        else
          email_subject = "Invalid Stripe Payment Detected (Automatic Prevention Failed) - #{stripe_invoice_id}"
          email_title = 'A potential erroneous charge has been detected, but could not be canceled, please review Stripe ASAP'
          email_body = 'The invoice validation process detected an invalid payment but could not prevent it from going through.<br><br>' \
            + '<strong>Error Message:</strong> ' + invoice_closing_error.to_s + '<br><br>The subscription id ' \
            + 'did not match any groups in the database which is a likely indication of an erroneous subscription which needs to be ' \
            + 'manually canceled in Stripe. Please click the link below to investigate.'
          color = 'red'
        end
        if ENV['stripe_livemode'] == 'true'
          email_link = "https://dashboard.stripe.com/invoices/#{stripe_invoice_id}"
        else
          email_link = "https://dashboard.stripe.com/test/invoices/#{stripe_invoice_id}"
        end
        SystemMailer.bl_admin_email(email_subject, email_title, email_body, 'Open invoice in stripe', email_link, color).deliver
      end
    end
  end

  # Calls out to stripe to cancel subscription, returns a poller which can be used to track the progress
  # NOTE: Do not set the stripe_subscription_status to 'canceled' directly, always use this method (or the class method below).
  def cancel_stripe_subscription
    if stripe_subscription_id.present?
      poller = Poller.new
      poller.save
      Group.delay(queue: 'high', retry: false).cancel_stripe_subscription(stripe_subscription_id, poller_id: poller.id)
      poller.id
    else
      raise StandardError.new('This group does not have an active subscription!')
    end
  end

  # Calls out to stripe to cancel subscription then updates the subscription status of any group with the specified subscription id
  # Accepts the following options (leave the group fields out to skip the group updating)
  # - poller_id: If provided this poller record will be updated with success or failure details
  # - throw_errors: Set this to true to throw errors instead of logging them
  # - context: Set this to 'stripe' if calling from a stripe webhook (this will skip the calls back out to stripe)
  def self.cancel_stripe_subscription(stripe_subscription_id, options = {})
    begin
      poller = Poller.find(options[:poller_id]) rescue nil
      group = Group.find_by(stripe_subscription_id: stripe_subscription_id) rescue nil

      if group.present? && group.stripe_push_pending
        # This is a webhook event coming in while Group.cancel_stripe_subscription is running, so we ignore it
        group.info_items.new(
          type: 'stripe-event-ignored', 
          name: 'Ignored Stripe Event (Group.cancel_stripe_subscription)',
          data: options
        ).save
      else
        if group
          # First we need to record that we are working on the subscription (so any incoming stripe webhooks will be ignored until we're done)
          group.stripe_push_pending = true
          group.save
        end
        
        if options[:context] != 'stripe'
          subscription = Stripe::Subscription.retrieve(stripe_subscription_id)
          subscription = subscription.delete
        end
        
        if group
          group.context = options[:context]
          group.stripe_subscription_status = 'canceled'
          group.stripe_subscription_id = nil
          group.stripe_subscription_card = nil
          group.subscription_end_date = 2.weeks.from_now
          group.stripe_subscription_details = subscription.to_hash if subscription.present?
          group.stripe_push_pending = false
          group.save!

          # Track an info item (which can potentially be user-facing)
          group.info_items.new(
            type: 'group-subscription-canceled',
            name: 'Group Subscription was Successfully Canceled',
            data: { stripe_subscription_id: stripe_subscription_id, subscription_plan: group.subscription_plan,
              owner_id: group.owner_id.to_s }
          ).save

          # Then log an event in intercom
          IntercomEventWorker.perform_async({
            'event_name' => 'stripe-subscription-cancel',
            'email' => group.owner.email,
            'created_at' => Time.now.to_i,
            'metadata' => {
              'group_id' => group.id.to_s,
              'group_name' => group.name,
              'group_url' => group.group_url,
              'plan' => group.subscription_plan
            }
          })
        end

        if poller
          poller.status = 'successful'
          poller.message = 'Group subscription successfully cancelled.'
          poller.data = subscription.to_hash if subscription.present?
          poller.save
        end
      end
    rescue Exception => e
      if group && group.stripe_push_pending
        group.stripe_push_pending = false
        group.save
      end

      if poller
        poller.status = 'failed'
        poller.message = 'An error occurred while trying to cancel the subscription, ' \
          + "please try again. (Error message: #{e})"
        poller.save
      elsif options[:throw_errors]
        throw e
      else
        # Log this error
        InfoItem.new(
          type: 'stripe-error',
          name: 'Problem Cancelling Subscription (Group.cancel_stripe_subscription)',
          data: { stripe_subscription_id: stripe_subscription_id, options: options, error: e.to_s }
        ).save
      end
    end
  end
  
protected

  def add_creator_to_admins
    if creator.present?
      self.admins << self.creator
      self.creator.save
    end

    true
  end

  # This is a mongoid relation callback that fires every time a new member is added to the group.
  # It checks to see if there are any group welcome actions to do and then does them.
  def do_group_welcome(user)
    badge_ids = [] # default this to a blank array

    # First check to see if we need to join to any badges
    if !welcome_badge_tag.blank?
      if welcome_badge_tag == WELCOME_BADGE_TAG_ALL_BADGES
        badge_query = badges
      else
        group_tag = tags.find_by(name: welcome_badge_tag.downcase) rescue nil
        if group_tag
          badge_query = group_tag.badges
        end
      end

      if badge_query
        badge_query.each do |badge|
          badge_ids << badge.id
          badge.add_learner user
        end
      end
    end

    # Then send the welcome message email if there's a welcome message
    if !welcome_message.blank?
      UserMailer.delay.group_welcome_message(user.id, self.id, badge_ids)
    end
  end

  def update_counts
    current_member_count = member_ids.count
    current_admin_count = admin_ids.count

    if (current_member_count != member_count) || (current_admin_count != admin_count)
      self.member_count = current_member_count
      self.admin_count = current_admin_count
      self.total_user_count = current_member_count + current_admin_count
    end
  end

  def set_default_values
    self.owner ||= self.creator

    if !website.blank? && !website.downcase.start_with?("http")
        self.website = "http://#{website}"
    end
    if !image_url.blank? && !image_url.downcase.start_with?("http")
        self.image_url = "http://#{image_url}"
    end
  end
  
  def update_avatar_key
    if new_record? || avatar_key_changed?
      self.direct_avatar.key = avatar_key
      self.processing_avatar = true
    end
  end

  def process_avatar
    if processing_avatar
      Group.delay(queue: 'high', retry: 5).do_process_avatar(id)
    end
  end

  # Processes changes to the image from carrierwave direct key
  def self.do_process_avatar(group_id)
    group = Group.find(group_id)
    group.processing_avatar = false

    if !group.direct_avatar.blank?
      group.remote_avatar_url = group.direct_avatar.direct_fog_url(with_path: true)
      
      if group.save
        # If it worked then update all of the child badges
        Group.delay(queue: 'low').update_child_badge_fields(group_id)
      else
        # If there was an error then clear out the uploaded image and use the default
        group.avatar_key = nil
        group.save! # This should trigger the callback again calling a new instance of this method
      end
    else
      # Use the default image
      group.avatar = Rails.root.join(DEFAULT_GROUP_AVATAR_PATH).open
      group.save!
    end
  end

  def update_validated_fields
    # This should make it impossible to ever trigger the max description length validation
    if description && (description.length > MAX_DESCRIPTION_LENGTH)
      self.description = description[0, MAX_DESCRIPTION_LENGTH]
    end

    # This should make it impossible to ever trigger the max location length validation
    if location && (location.length > MAX_LOCATION_LENGTH)
      self.location = location[0, MAX_LOCATION_LENGTH]
    end
  end

  def update_caps_field
    if url_with_caps.nil?
      self.url = nil
    else
      self.url = url_with_caps.downcase
    end
  end

  def copy_errors
    if errors && !errors[:url].blank?
      errors[:name] = errors[:url]
    end
  end

  def new_owner_username_exists
    unless new_owner_username.blank?
      new_owner = User.find(new_owner_username) rescue nil
      
      if new_owner.nil?
        errors.add(:new_owner_username, " is not a valid Badge List username")
      end
    end
  end

  def change_owner
    if new_owner_username && new_owner_username_changed?
      new_owner = User.find(new_owner_username) rescue nil
      if new_owner && (owner_id != new_owner.id)
        self.previous_owner_id = self.owner_id
        self.owner = new_owner
        self.admins << new_owner unless self.admin_ids.include? new_owner.id

        # Cancel the subscription if needed 
        # NOTE: This callback runs AFTER process_subscription_field_updates
        if paid?
          set_flag PENDING_SUBSCRIPTION_FLAG
          cancel_stripe_subscription # asyn callout to stripe which updates status when done
        end

        # Notify the new owner
        unless new_owner.email_inactive
          GroupMailer.delay(queue: 'low').group_transfer(id, new_owner.id, previous_owner_id)
        end
      end
      self.new_owner_username = nil
    end
  end

  # Updates the cached group info on child badges if needed
  def update_child_badges
    if name_changed? || url_with_caps_changed?
      Group.delay(queue: 'low').update_child_badge_fields(self.id)
    end
  end

  # Any changes toe tags_cache cause a complete rebuild of top_user_tags_cache && top_badges
  def process_tags_cache_changes
    if tags_cache_changed?
      self.top_user_tags_cache = tags_cache.values.sort_by do |tag_item| 
        # Sort first by the magnitude descending, then by name ascending
        [tag_item['user_magnitude']*-1, tag_item['name']]
      end
      self.top_badge_tags_cache = tags_cache.values.sort_by do |tag_item|
        # Sort first by the magnitude descending, then by name ascending
        [tag_item['badge_magnitude']*-1, tag_item['name']]
      end
    end
  end

  # === SUBSCRIPTION-RELATED === #

  # Validates any subscription related field logic
  def subscription_fields_valid
    if paid?
      errors.add(:subscription_plan, 'is required') unless subscription_plan
    end
  end

  def update_paid_defaults
    if new_record? || type_changed?
      unless (type == 'paid')  && (type_was == 'private')
        # The above is a one-time conditional needed during the migration from private to paid
        self.badge_copyability = (has?(:privacy)) ? 'admins' : 'public'
      end
      self.joinability = 'closed' if paid?
    end
  end

  # Updates flags and subscription metadata whenever the plan or status changes
  def process_subscription_field_updates
    if paid?
      refresh_subscription_on_revive = false

      if revive_subscription # set by the group form when reviving a subscription
        if stripe_subscription_status == 'new'
          self.stripe_subscription_status = 'force-new' # forces dirty state to fire callback
        else
          self.stripe_subscription_status = 'new'
        end
        self.revive_subscription = nil
        refresh_subscription_on_revive = true # manually trigger the refresh of the features and clearing of the subscription end date
      elsif stripe_subscription_status.blank? # will be true on new group record
        self.stripe_subscription_status = 'new'
      elsif subscription_plan_changed? && (context != 'stripe')
        self.stripe_subscription_status = 'pending'
      end

      if new_record? || stripe_subscription_status_changed?
        case stripe_subscription_status
        when 'new', 'force-new', 'pending', 'trialing', 'active', 'past_due'
          clear_flag PENDING_SUBSCRIPTION_FLAG
        when 'unpaid'
          set_flag PENDING_SUBSCRIPTION_FLAG
        when 'canceled'
          set_flag PENDING_SUBSCRIPTION_FLAG

          # Notify the user that their group is canceled
          GroupMailer.delay(retry: 5, queue: 'low').subscription_canceled(id)
        else
          set_flag PENDING_SUBSCRIPTION_FLAG
        end
      end

      if new_record? || subscription_plan_changed? || refresh_subscription_on_revive
        self.subscription_end_date = nil if (context != 'stripe')

        clear_subscription_limit_overrides
        if ALL_SUBSCRIPTION_PLANS[subscription_plan]
          refresh_subscription_features
        else
          self.features = []
        end
      end
    else
      self.subscription_plan = nil unless stripe_subscription_id
    end
  end

  # This fires when there is a new subscription or an update to an existing subscription (including changing the payment method).
  # This will *not* fire if context is `stripe`.
  def push_stripe_changes
    if paid? && (context != 'stripe') \
        && (revive_subscription || \
          ((stripe_subscription_status != 'canceled') \
            && (stripe_subscription_status_changed? || subscription_plan_changed? || stripe_subscription_card_changed?)))
      Group.delay_for(30.seconds, queue: 'high').push_to_stripe(id)
    end
  end

  # Called after an update (not on insert) to check if stripe subscription metadata needs updating
  # It is possible that both this and push_stripe_changes will fire in the same transaction so this purposely delays for a bit longer
  def push_stripe_metadata_changes
    if paid? && stripe_subscription_metadata_changed?
      Group.delay_for(3.minutes, queue: 'low', retry: false).push_metadata_to_stripe(id)
    end
  end

  # Cancels the stripe subscription when destroying a paid group
  def cancel_subscription_on_destroy
    if stripe_subscription_id.present?
      cancel_stripe_subscription # asynchronous
    end
  end

  #=== ANALYTICS ===#

  def update_analytics
    if new_record?
      IntercomEventWorker.perform_async({
        'event_name' => 'group-create',
        'email' => ((creator.present?) ? creator.email : nil),
        'created_at' => Time.now.to_i,
        'metadata' => {
          'group_id' => id.to_s,
          'group_name' => name,
          'group_url' => group_url,
          'group_type' => type
        }
      })
    end
  end

end
