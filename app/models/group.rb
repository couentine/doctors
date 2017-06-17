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
  TYPE_VALUES = ['open', 'closed', 'private']
  JSON_FIELDS = [:name, :location, :type, :member_count, :admin_count, :total_user_count]
  JSON_MOCK_FIELDS = { 'image_url' => :avatar_image_url, 'url' => :issuer_website,
    'badge_count' => :badge_count, 'slug' => :url_with_caps, 'full_url' => :group_url,
    'badges' => :badge_urls_with_caps }
  VISIBILITY_VALUES = ['public', 'private']
  COPYABILITY_VALUES = ['public', 'members', 'admins']
  TAG_ASSIGNABILITY_VALUES = ['members', 'admins']
  TAG_CREATABILITY_VALUES = ['members', 'admins']
  TAG_VISIBILITY_VALUES = ['public', 'members', 'admins']
  WELCOME_BADGE_TAG_ALL_BADGES = '***ALL BADGES***'

  JSON_TEMPLATES = {
    list_item: [:id, :name, :url, :url_with_caps, :location, :type, :member_count, :admin_count, 
      :total_user_count, :avatar_image_url, :avatar_image_medium_url, :avatar_image_small_url,
      :badge_count, :full_url, :full_path],
    simple_list_item_with_tags: [:id, :name, :url, :url_with_caps, :tags_cache]
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

  # === RELATIONSHIPS === #

  belongs_to :creator, inverse_of: :created_groups, class_name: 'User'
  belongs_to :owner, inverse_of: :owned_groups, class_name: 'User'
  has_and_belongs_to_many :admins, inverse_of: :admin_of, class_name: 'User'
  has_and_belongs_to_many :members, inverse_of: :member_of, class_name: 'User'
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
  field :type,                            type: String, default: 'open'
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
  field :tag_assignability,                type: String, default: 'members'
  field :tag_creatability,                type: String, default: 'members'
  field :tag_visibility,                  type: String, default: 'public'
  
  field :user_limit,                      type: Integer, default: 5
  field :admin_limit,                     type: Integer, default: 1
  field :sub_group_limit,                 type: Integer, default: 0
  field :features,                        type: Array, default: [] # = ['community', 'branding']
  field :feature_grant_reporting,         type: Boolean # Manually grants the reporting feature
  field :total_user_count,                type: Integer, default: 1
  field :admin_count,                     type: Integer, default: 1
  field :member_count,                    type: Integer, default: 0
  field :sub_group_count,                 type: Integer, default: 0
  field :active_user_count,               type: Integer # RETIRED
  field :monthly_active_users,            type: Hash # RETIRED
  
  field :pricing_group,                   type: String, default: 'standard'
  field :subscription_plan,               type: String # values are defined in config.yml
  field :subscription_end_date,           type: Time
  field :stripe_payment_fail_date,        type: Time
  field :stripe_payment_retry_date,       type: Time
  field :stripe_subscription_card,        type: String
  field :stripe_subscription_id,          type: String
  field :stripe_subscription_details,     type: String
  field :stripe_subscription_status,      type: String, default: 'new'
    # Possible Status Values = ['trialing', 'active', 'past_due', 'canceled', 'unpaid'] 
    #                          & 'new' & 'force-new'
  field :new_subscription,                type: Boolean # used to set subscription status to 'new'

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
  validates :creator, presence: true
  
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
  
  before_save :update_private_defaults
  before_save :process_subscription_field_updates
  before_create :create_first_subscription
  after_save :process_avatar
  before_update :create_another_subscription
  after_update :update_child_badges
  before_save :process_tags_cache_changes
  after_update :update_stripe_if_needed
  before_destroy :cancel_subscription_on_destroy
  
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
    private? && ( \
      ((stripe_subscription_status == 'canceled') && (Time.now >= subscription_end_date)) \
        || (stripe_subscription_status == 'unpaid')
    )
  end

  def can_add_members?(how_many = 1)
    public? || ((user_limit < 0) || ((member_count + how_many) <= user_limit))
  end

  # Returns hash = {
  #   color: 'default' or 'red'
  #   label: one_or_two_word_summary_of_current_status,
  #   summary: contents_of_detail_tooltip,
  #   requires_attention: true or false
  # }
  def member_limit_details
    if public? || user_limit.blank?
      { color: 'default', requires_attention: false, label: 'Unlimited', 
        summary: 'Public groups support unlimited members.' }
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

  def can_add_admins?(how_many = 1)
    public? || ((admin_limit < 0) || ((admin_count + how_many) <= admin_limit))
  end

  # Returns hash = {
  #   color: 'default' or 'red'
  #   label: one_or_two_word_summary_of_current_status,
  #   summary: contents_of_detail_tooltip,
  #   requires_attention: true or false
  # }
  def admin_limit_details
    if public? || admin_limit.blank?
      { color: 'default', requires_attention: false, label: 'Unlimited', 
        summary: 'Public groups support unlimited admins.' }
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

  def can_create_sub_groups?
    public? || ((sub_group_limit < 0) || (sub_group_count < sub_group_limit))
  end

  # Returns whether or not the features array contains the specified 'feature' or :feature
  def has?(feature)
    return_value = !features.blank? && features.include?(feature.to_s)
    
    # Enable manual grant of the reporting feature
    if (feature.to_s == 'reporting')
      return_value ||= (feature_grant_reporting == true)
    end

    return_value
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
    if private?
      case stripe_subscription_status
      when 'trialing', 'new', 'force-new'
        'Trial'
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
    if public?
      { color: 'green', summary: 'Free open group', icon: 'fa-check-circle', show_alert: false }
    else
      date_failed = stripe_payment_fail_date || Time.now
      date_retry = stripe_payment_retry_date || (Time.now + 3.days)

      case stripe_subscription_status
      when 'new', 'force-new', 'trialing'
        { color: 'orange', summary: "Trial ends on " \
            + "#{(subscription_end_date || 2.weeks.from_now).to_s(:short_date)}", 
          icon: 'fa-clock-o', show_alert: true,
          summary: "Trial ends on " \
            + "#{(subscription_end_date || 2.weeks.from_now).to_s(:short_date)}",
          alert_title: "Group is in trial period",
          alert_body: ("Your private group trial ends on " \
                      + "#{(subscription_end_date || 2.weeks.from_now).to_s(:short_date)}. " \
                      + "Your card will be charged when the trial is complete. " \
                      + "If you have any questions, send us an email at " \
                      + "<a href='mailto:solutions@badgelist.com'>solutions@badgelist.com" \
                      + "</a>.").html_safe }
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
            + "the group type to public. You can also choose to cancel your subscription which " \
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
          summary: "Subscription renews #{subscription_end_date.to_s(:short_date)}" }
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
    if private? && \
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

  # Is this group visible to the public?
  def public?
    (type == 'open') || (type == 'closed')
  end
  
  def private?
    type == "private"
  end

  # Does this group have open membership?
  def open?
    (type == 'open')
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

  # === STRIPE RELATED METHODS === #

  # This method will refresh the limits fields from the ALL_SUBSCRIPTION_PLANS configuration 
  def refresh_subscription_limits
    if !subscription_plan.blank? && ALL_SUBSCRIPTION_PLANS.has_key?(subscription_plan)
      self.user_limit = ALL_SUBSCRIPTION_PLANS[subscription_plan]['users']
      self.admin_limit = ALL_SUBSCRIPTION_PLANS[subscription_plan]['admins']
      self.sub_group_limit = ALL_SUBSCRIPTION_PLANS[subscription_plan]['sub_groups']
    end
  end

  # This method will refresh the features field from the ALL_SUBSCRIPTION_PLANS configuration 
  def refresh_subscription_features
    if !subscription_plan.blank? && ALL_SUBSCRIPTION_PLANS.has_key?(subscription_plan)
      self.features = ALL_SUBSCRIPTION_PLANS[subscription_plan]['features']
    end
  end
  
  # Calls out to stripe to create new subscription for the group
  # Set async to true to do the call asynchronously
  # NOTE: No poller is created for this async since group callbacks already set intelligent defaults
  def create_stripe_subscription(async = false)
    if async
      Group.delay(queue: 'high').create_stripe_subscription(group_id: self.id)
    else
      Group.create_stripe_subscription(group: self)
    end
  end

  # Calls out to stripe to create new subscription for the group
  # Accepts the following options:
  # - group_id: Include this to have the group be queried
  # - group: Include this to skip the query
  # - trial_end: Manually sets the trial end date (should be unix timestamp)
  def self.create_stripe_subscription(options = {})
    group = options[:group] || Group.find(options[:group_id])

    customer = Stripe::Customer.retrieve(group.owner.stripe_customer_id)
    if (customer.default_source != group.stripe_subscription_card)
      customer.default_source = group.stripe_subscription_card
      customer.save
      
      group.owner.stripe_default_source = group.stripe_subscription_card
      group.owner.save
    end

    subscription = customer.subscriptions.create(
      plan: group.subscription_plan,
      trial_end: options[:trial_end],
      metadata: {
        description: "#{group.name} (#{group.url})",
        group_id: group.id.to_s,
        group_url: group.url,
        group_name: group.name,
        group_website: group.website
      }
    )
    
    group.stripe_subscription_id = subscription.id
    group.stripe_subscription_status = subscription.status
    group.stripe_subscription_details = subscription.to_hash
    group.subscription_end_date = subscription.current_period_end
    group.save
  end

  # Calls out to stripe to refresh the subscription status (Called from the stripe webhook)
  # Accepts the following options hash members:
  # - group: This will cause the group query to be skipped
  # - context: This will override the default group context value
  # - payment_fail_date: This will optionally cause the payment_fail_date to be updated
  # - payment_retry_date: This will optionally cause the payment_retry_date to be updated
  # - info_item_data: This will optionally result in the insertion of an info item 
  #     with type = "stripe-event" and name = "Invoice Payment"
  # - throw_errors: Set this to true to throw errors instead of logging them
  # - queue_send_trial_ending_email: 
  #     Set to true to send the trial_ending email 3 days before end
  #     Note: If this is a free group the trial_ending email will NOT be sent even if param is true
  def self.refresh_stripe_subscription(stripe_subscription_id, options = {})
    begin
      group = options[:group] \
        || (Group.find_by(stripe_subscription_id: stripe_subscription_id) rescue nil)
      group.context = options[:context]

      if options[:info_item_data]
        group.info_items.new(type: 'stripe-event', name: 'Invoice Payment', \
          data: options[:info_item_data], user: group.owner).save
      end

      customer = Stripe::Customer.retrieve(group.owner.stripe_customer_id)
      begin
        subscription = customer.subscriptions.retrieve(group.stripe_subscription_id)
        
        group.subscription_plan = subscription.plan.id
        group.stripe_subscription_status = subscription.status
        group.stripe_subscription_details = subscription.to_hash
        group.subscription_end_date = subscription.current_period_end
        group.stripe_payment_fail_date = options[:payment_fail_date]
        group.stripe_payment_retry_date = options[:payment_retry_date]
        group.save

        if options[:queue_send_trial_ending_email] && subscription && subscription.plan \
            && (subscription.plan.amount > 0)
          # Schedule a reminder email to go out 3 days before the trial expires
          GroupMailer.delay_until(group.subscription_end_date - 3.days, retry: 5, queue: 'low')\
            .trial_ending(group.id)
        end
      rescue Exception => e
        if subscription
          # There was an unanticipated error, throw it
          throw e
        else
          # There is no more subscription (it must've been cancelled remotely), cancel it locally
          group.stripe_subscription_status = 'canceled'
          group.save
        end
      end
    rescue Exception => e
      if options[:throw_errors]
        throw e
      else
        # Log this error
        item = InfoItem.new
        item.type = 'webhook-error'
        item.name = 'Stripe Webhook Error (Group.refresh_stripe_subscription)'
        item.data = { stripe_subscription_id: stripe_subscription_id, options: options, e: e.to_s }
        item.save
      end
    end
  end

  # Calls out to stripe to update stripe about local changes to the subscription
  # Set async to true to do the call asynchronously
  # NOTE: No poller is created for this async since its only called by callbacks
  def update_stripe_subscription(async = false)
    if async
      Group.delay(queue: 'high').update_stripe_subscription(group_id: self.id)
    else
      Group.update_stripe_subscription(group: self)
    end
  end
  
  # Calls out to stripe to update stripe about local changes to the subscription
  # Accepts the following options:
  # - group_id: Include this to have the group be queried
  # - group: Include this to skip the query
  # - throw_errors: Set this to true to throw errors instead of logging them
  def self.update_stripe_subscription(options = {})
    begin
      group = options[:group] || Group.find(options[:group_id])

      customer = Stripe::Customer.retrieve(group.owner.stripe_customer_id)
      if customer.default_source != group.stripe_subscription_card
        customer.default_source = group.stripe_subscription_card
        customer.save
      end
      
      subscription = customer.subscriptions.retrieve(group.stripe_subscription_id)
      if group.subscription_plan != subscription.plan
        subscription.plan = group.subscription_plan
        subscription.save
      end
    rescue Exception => e
      if options[:throw_errors]
        throw e
      else
        # Log this error
        item = InfoItem.new
        item.type = 'callback-error'
        item.name = 'Problem Updating Subscription (Group.update_stripe_subscription)'
        item.data = { options: options, error: e.to_s }
        item.save
      end
    end
  end

  # Calls out to stripe to cancel subscription
  # Set update_status to decide whether or not the status will get updated the cancellation
  # If async is set to true then the method will return the id of a poller
  def cancel_stripe_subscription(update_status, async = false)
    if async
      poller = Poller.new
      poller.save
      group_id = (update_status) ? self.id : nil
      Group.delay(queue: 'high', retry: false).cancel_stripe_subscription(owner.stripe_customer_id,\
        stripe_subscription_id, poller_id: poller.id, group_id: group_id)
      poller.id
    else
      group = (update_status) ? self : nil
      Group.cancel_stripe_subscription(owner.stripe_customer_id, stripe_subscription_id, \
        group: group)
    end
  end

  # Calls out to stripe to cancel subscription
  # Accepts the following options (leave the group fields out to skip the group updating)
  # - group_id: Include this to have the group be queried and updated by id
  # - group: Include this to have the group be updated without requerying
  # - poller_id: If provided this poller record will be updated with success or failure details
  # - throw_errors: Set this to true to throw errors instead of logging them
  def self.cancel_stripe_subscription(stripe_customer_id, stripe_subscription_id, options = {})
    begin
      poller = Poller.find(options[:poller_id]) rescue nil
      customer = Stripe::Customer.retrieve(stripe_customer_id)
      subscription = customer.subscriptions.retrieve(stripe_subscription_id)
      subscription = subscription.delete
      
      group = options[:group] || Group.find(options[:group_id]) rescue nil
      if group
        group.stripe_subscription_status = 'canceled'
        group.stripe_subscription_details = subscription.to_hash
        group.save
      end

      if poller
        poller.status = 'successful'
        poller.message = 'You have successfully cancelled your subscription.'
        poller.data = subscription.to_hash
        poller.save
      end
    rescue Exception => e
      if poller
        poller.status = 'failed'
        poller.message = 'An error occurred while trying to cancel your subscription, ' \
          + "please try again. (Error message: #{e})"
        poller.save
      elsif options[:throw_errors]
        throw e
      else
        # Log this error
        item = InfoItem.new
        item.type = 'callback-error'
        item.name = 'Problem Cancelling Subscription (Group.cancel_stripe_subscription)'
        item.data = { stripe_customer_id: stripe_customer_id, options: options, error: e.to_s,
          stripe_subscription_id: stripe_subscription_id }
        item.save
      end
    end
  end
  
protected

  def add_creator_to_admins
    self.admins << self.creator unless self.creator.blank?
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
        Group.delay(queue: 'low').update_child_badge_fields(self.id)
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
        if private?
          set_flag PENDING_SUBSCRIPTION_FLAG
          self.stripe_subscription_status = 'canceled'
          self.stripe_subscription_id = nil
          self.stripe_subscription_card = nil
          self.subscription_end_date = 2.weeks.from_now
        end

        # Notify the new owner
        unless new_owner.email_inactive
          GroupMailer.delay(queue: 'low').group_transfer(id)
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
    if private?
      errors.add(:subscription_plan, 'is required') unless subscription_plan
    end
  end

  def update_private_defaults
    if new_record? || type_changed?
      # Overwrite the badge copyability setting when we change between open & private
      self.badge_copyability = (private?) ? 'admins' : 'public'
    end
  end

  # Updates flags and subscription metadata whenever the plan or status changes
  def process_subscription_field_updates
    if private?
      if new_subscription
        if stripe_subscription_status == 'new'
          self.stripe_subscription_status = 'force-new' # forces dirty state to fire callback
        else
          self.stripe_subscription_status = 'new'
        end
        self.new_subscription = nil
      end

      if new_record? || stripe_subscription_status_changed?
        case stripe_subscription_status
        when 'new', 'force-new', 'trialing', 'active', 'past_due'
          clear_flag PENDING_SUBSCRIPTION_FLAG
        when 'unpaid'
          set_flag PENDING_SUBSCRIPTION_FLAG
        when 'canceled'
          set_flag PENDING_SUBSCRIPTION_FLAG
          self.stripe_subscription_id = nil
          self.stripe_subscription_card = nil
          self.subscription_end_date = 2.weeks.from_now

          # Notify the user that their group is canceled
          GroupMailer.delay(retry: 5, queue: 'low').subscription_canceled(id)
        else
          set_flag PENDING_SUBSCRIPTION_FLAG
        end
      end

      if new_record? || subscription_plan_changed?
        if ALL_SUBSCRIPTION_PLANS[subscription_plan]
          self.user_limit = ALL_SUBSCRIPTION_PLANS[subscription_plan]['users']
          self.admin_limit = ALL_SUBSCRIPTION_PLANS[subscription_plan]['admins']
          self.sub_group_limit = ALL_SUBSCRIPTION_PLANS[subscription_plan]['sub_groups']
          self.features = ALL_SUBSCRIPTION_PLANS[subscription_plan]['features']
        else
          self.user_limit = 5
          self.admin_limit = 1
          self.sub_group_limit = 0
          self.features = []
        end
      end
    else
      self.subscription_plan = nil unless stripe_subscription_id
    end
  end

  # This creates the initial stripe subscription if this is a private group
  def create_first_subscription
    if private? && (stripe_subscription_status == 'new')
      create_stripe_subscription(true) # asynchronous
      
      # Default to a 2 week trial (until we hear back from strip via webhook)
      self.stripe_subscription_status = 'trialing'
      self.subscription_end_date = 2.weeks.from_now
    end
  end

  # This creates a new subscription when status moves to new
  def create_another_subscription
    if private? && stripe_subscription_status_changed? \
        && ((stripe_subscription_status == 'new') || (stripe_subscription_status == 'force-new'))
      if !stripe_subscription_id.blank? 
        # Then first we cancel the existing subscription (but don't update sub status after)
        cancel_stripe_subscription(false, true); # asynchronous
      end

      create_stripe_subscription(true) # asynchronous
      
      # Default to a 2 week trial (until we hear back from strip via webhook)
      self.stripe_subscription_status = 'trialing'
      self.subscription_end_date = 2.weeks.from_now
    end
  end

  # Updates core fields in stripe if they change locally 
  # NOTE: It won't run if this callback is being fired by stripe itself
  def update_stripe_if_needed
    if private? && !stripe_subscription_id.blank? && (context != 'stripe') \
        && (subscription_plan_changed? || stripe_subscription_card_changed?)
      update_stripe_subscription(true) # asynchronous

      # Then update analytics
      IntercomEventWorker.perform_async({
        'event_name' => 'stripe-subscription-update',
        'email' => owner.email,
        'created_at' => Time.now.to_i,
        'metadata' => {
          'group_id' => id.to_s,
          'group_name' => name,
          'group_url' => group_url,
          'group_type' => type,
          'old_plan' => subscription_plan_was,
          'new_plan' => subscription_plan
        }
      })
    end
  end

  # Cancels the stripe subscription when destroying a private group
  def cancel_subscription_on_destroy
    if !stripe_subscription_id.blank?
      cancel_stripe_subscription(false, true); # asynchronous
    end
  end

  #=== ANALYTICS ===#

  def update_analytics
    if new_record?
      IntercomEventWorker.perform_async({
        'event_name' => 'group-create',
        'email' => creator.email,
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
