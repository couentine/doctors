class Group
  include Mongoid::Document
  include Mongoid::Timestamps
  include JSONFilter

  # === CONSTANTS === #

  MAX_NAME_LENGTH = 50
  MAX_URL_LENGTH = 30
  MAX_LOCATION_LENGTH = 200
  TYPE_VALUES = ['open', 'closed', 'private']
  JSON_FIELDS = [:name, :location, :type]
  JSON_MOCK_FIELDS = { 'slug' => :url_with_caps, 'url' => :issuer_website, 'image' => :image_url,
    'email' => :primary_email }

  CUSTOMER_CODE_VALUES = ['valid_customer_code', 'kstreem', 'london-21', 'tokyo-15',
    'paris-99', 'budapest-54', 'chicago-67', 'santiago-12'] # add new customers here

  PENDING_TRANSFER_FLAG = 'pending_transfer'
  PENDING_SUBSCRIPTION_FLAG = 'pending_subscription'

  # === INSTANCE VARIABLES === #

  attr_accessor :context # Used to prevent certain callbacks from firing in certain contexts

  # === RELATIONSHIPS === #

  belongs_to :creator, inverse_of: :created_groups, class_name: "User"
  belongs_to :owner, inverse_of: :owned_groups, class_name: "User"
  has_and_belongs_to_many :admins, inverse_of: :admin_of, class_name: "User"
  has_and_belongs_to_many :members, inverse_of: :member_of, class_name: "User"
  has_many :badges, dependent: :restrict # You have to delete all the badges FIRST

  # === FIELDS & VALIDATIONS === #

  field :name,                        type: String
  field :url,                         type: String
  field :url_with_caps,               type: String
  field :location,                    type: String
  field :website,                     type: String
  field :image_url,                   type: String
  field :type,                        type: String, default: 'private'
  field :customer_code,               type: String
  field :validation_threshold,        type: Integer, default: 1
  field :invited_admins,              type: Array, default: []
  field :invited_members,             type: Array, default: []
  field :flags,                       type: Array, default: []
  field :new_owner_username,          type: String
  
  field :user_limit,                  type: Integer, default: 5
  field :admin_limit,                 type: Integer, default: 1
  field :sub_group_limit,             type: Integer, default: 0
  field :total_user_count,            type: Integer, default: 0
  field :admin_count,                 type: Integer, default: 0
  field :member_count,                type: Integer, default: 0
  field :sub_group_count,             type: Integer, default: 0
  field :active_user_count,           type: Integer, default: 0
  field :monthly_active_users,        type: Hash, default: {}, pre_processed: true
  
  field :pricing_group,               type: String, default: 'standard'
  field :subscription_plan,           type: String # values are defined in config.yml
  field :subscription_end_date,       type: Time
  field :stripe_subscription_card,    type: String
  field :stripe_subscription_id,      type: String
  field :stripe_subscription_details, type: String
  field :stripe_subscription_status,  type: String # Possible Status Values = ['trialing', 'active',
                                                   #  'past_due', 'canceled', 'unpaid']

  validates :name, presence: true, length: { within: 5..MAX_NAME_LENGTH }
  validates :url_with_caps, presence: true, uniqueness: true, length: { within: 2..MAX_URL_LENGTH }, 
            format: { with: /\A[\w-]+\Z/, message: "can only contain letters, numbers, dashes and underscores" },
            exclusion: { in: APP_CONFIG['blocked_url_slugs'],
                         message: "%{value} is a specially reserved url." }
  validates :url, presence: true, uniqueness: true, length: { within: 2..MAX_URL_LENGTH }, 
            format: { with: /\A[\w-]+\Z/, message: "can only contain letters, numbers, dashes and underscores" },
            exclusion: { in: APP_CONFIG['blocked_url_slugs'],
                         message: "%{value} is a specially reserved url." }
  validates :location, length: { maximum: MAX_LOCATION_LENGTH }
  validates :website, url: true
  validates :image_url, url: true
  validates :type, inclusion: { in: TYPE_VALUES, 
                                message: "%{value} is not a valid Group Type" }
  validates :creator, presence: true
  
  validate :new_owner_username_exists
  validate :subscription_fields_valid

  # Which fields are accessible?
  attr_accessible :name, :url_with_caps, :location, :website, :image_url, :type, :customer_code, 
    :validation_threshold, :new_owner_username, :user_limit, :admin_limit, :sub_group_limit,
    :pricing_group, :subscription_plan, :stripe_subscription_card

  # === CALLBACKS === #

  before_validation :set_default_values, on: :create
  before_validation :update_caps_field
  before_create :add_creator_to_admins
  before_update :change_owner
  before_save :update_counts
  before_save :process_subscription_updates
  after_save :queue_create_stripe_subscription_if_needed
  after_update :update_stripe_if_needed

  # === GROUP MOCK FIELD METHODS === #
  # These are used to mock the presence of certain fields in the JSON output.

  def primary_email; (!creator.nil?) ? creator.email : nil; end
  def issuer_website; (website.blank?) ? "#{ENV['root_url']}/#{url}" : website; end

  # === BADGE METHODS === #

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

  # === INSTANCE METHODS === #

  def to_param
    url
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

  # This function logs activity in the group by a user
  # If the user is a member or admin of the group they will be counted as a monthly active user
  def log_active_user(current_user)
    if current_user && (has_member?(current_user) || has_admin?(current_user))
      self.monthly_active_users = {} if monthly_active_users.nil?
      
      current_month_key = Time.now.to_s(:year_month)
      if !monthly_active_users.has_key? current_month_key
        self.monthly_active_users[current_month_key] = [current_user.username]
      elsif !monthly_active_users[current_month_key].include? current_user.username
        self.monthly_active_users[current_month_key] << current_user.username
      end
      
      if self.changed?
        if monthly_active_users.has_key?(current_month_key)
          self.active_user_count = monthly_active_users[current_month_key].count
        end
        self.timeless.save
      end
    end
  end

  # Returns URL of the group's logo (either from the image_url property or the Badge List default)
  def logo_url
    if image_url
      image_url
    else
      "#{ENV['root_url']}/assets/group-image-default.png"
    end
  end

  # === STRIPE RELATED METHODS === #

  # Calls out to stripe to create a new subscription for the provided group 
  # (subscription is created on the owner's customer record)
  
  def create_stripe_subscription
    Group.create_stripe_subscription(nil, self)
  end

  def self.create_stripe_subscription(group_id, group = nil) # provide group to skip query
    group = Group.find(group_id) if group.nil?

    if group && group.private? && group.stripe_subscription_id.blank? \
        && !group.subscription_plan.blank? && !group.stripe_subscription_card.blank? \
        && (subscription_status != 'canceled')
      customer = Stripe::Customer.retrieve(group.owner.stripe_customer_id)
      subscription = customer.subscriptions.create(
        plan: group.subscription_plan,
        source: group.stripe_subscription_card,
        metadata: {
          description: "#{group.name} (#{group.url})",
          group_id: group.id,
          group_url: group.url,
          group_name: group.name,
          group_website: group.website
        }
      ) if customer
      
      if customer && subscription
        group.stripe_subscription_id = subscription.id
        group.stripe_subscription_status = subscription.status
        group.stripe_subscription_details = subscription.to_hash
        group.subscription_end_date = subscription.current_period_end
        group.save
      end
    end
  end

  # Call this from after_save callback
  def queue_create_stripe_subscription_if_needed(queue = 'high')
    if private? && stripe_subscription_id.blank? && !subscription_plan.blank? \
        && !stripe_subscription_card.blank? && (subscription_status != 'canceled')
      Group.delay(queue: queue).create_stripe_subscription(id)
    end
  end

  # Calls out to stripe to refresh the subscription status
  
  def refresh_stripe_subscription
    Group.refresh_stripe_subscription(nil, self)
  end
  
  # This is called from the stripe webhook
  # Provide group to skip query
  def self.refresh_stripe_subscription(stripe_sub_id, group = nil, context = 'default')
    group = Group.find_by(stripe_subscription_id: stripe_sub_id) if group.nil?
    group.context = context

    if group && !group.stripe_subscription_id.blank? && !group.owner.stripe_customer_id.blank?
      customer = Stripe::Customer.retrieve(group.owner.stripe_customer_id)
      subscription = customer.subscriptions.retrieve(group.stripe_subscription_id) if customer
      
      if customer && subscription
        group.subscription_plan = subscription.plan.id
        group.stripe_subscription_status = subscription.status
        group.stripe_subscription_details = subscription.to_hash
        group.subscription_end_date = subscription.current_period_end
        group.save
      end
    end
  end

  # Calls out to stripe to update stripe about local changes to the subscription
  
  def update_stripe_subscription
    Group.update_stripe_subscription(nil, self)
  end
  
  def self.update_stripe_subscription(group_id, group = nil) # provide group to skip query
    group = Group.find(group_id) if group.nil?

    if group && !group.stripe_subscription_id.blank?
      customer = Stripe::Customer.retrieve(group.owner.stripe_customer_id)
      subscription = customer.subscriptions.retrieve(group.stripe_subscription_id) if customer
      
      if customer && subscription
        subscription.plan = group.subscription_plan,
        subscription.source = group.stripe_subscription_card,
        subscription.metadata = {
          description: "#{group.name} (#{group.url})",
          group_id: group.id,
          group_url: group.url,
          group_name: group.name,
          group_website: group.website
        }
        subscription.save
      end
    end
  end

  # Calls out to stripe to cancel subscription
  
  def cancel_stripe_subscription
    Group.cancel_stripe_subscription(nil, self)
  end
  
  def self.cancel_stripe_subscription(group_id, group = nil) # provide group to skip query
    group = Group.find(group_id) if group.nil?

    if group && !group.stripe_subscription_id.blank?
      customer = Stripe::Customer.retrieve(group.owner.stripe_customer_id)
      subscription = customer.subscriptions.retrieve(group.stripe_subscription_id) if customer
      
      if customer && subscription
        subscription = subscription.delete
        group.subscription_status = 'canceled'
        group.stripe_subscription_details = subscription.to_hash
        group.save
      end
    end
  end

  # LEFT OFF HERE: FIXME
  # Then work on cancelling subscriptions
  # Then figure out how to "fix" a subscription if it breaks
  # Then add model properties for UI limit display (think about how to communicate being over limit)
  # Then work on the webhook controller
  # Then UI? (check back in with list)
  
protected

  def add_creator_to_admins
    self.admins << self.creator unless self.creator.blank?
  end

  def update_counts
    if member_ids_changed? || admin_ids_changed?
      self.total_user_count = member_ids.count + admin_ids.count
    end

    self.member_count = member_ids.count if member_ids_changed?
    self.admin_count = admin_ids.count if admin_ids_changed?
  end

  def process_subscription_updates
    if new_record?
      if !subscription_plan.blank? && stripe_subscription_id.blank?
        # Default to a 2 week trial (until we hear back from strip via webhook)
        self.stripe_subscription_status = 'trialing'
        self.subscription_end_date = 2.weeks.from_now
      end
    else
      if stripe_subscription_status_changed?
        case stripe_subscription_status
        when 'trialing', 'active'
          clear_flag PENDING_SUBSCRIPTION_FLAG
        when 'past_due', 'unpaid'
          add_flag PENDING_SUBSCRIPTION_FLAG
        when 'canceled'
          add_flag PENDING_SUBSCRIPTION_FLAG
          self.stripe_subscription_id = nil
          self.stripe_subscription_card = nil
          self.subscription_end_date = 2.weeks.from_now
        else
          add_flag PENDING_SUBSCRIPTION_FLAG
        end
      end
    end

    if subscription_plan_changed?
      if ALL_SUBSCRIPTION_PLANS[subscription_plan]
        self.user_limit = ALL_SUBSCRIPTION_PLANS[subscription_plan]['users']
        self.admin_limit = ALL_SUBSCRIPTION_PLANS[subscription_plan]['admins']
        self.sub_group_limit = ALL_SUBSCRIPTION_PLANS[subscription_plan]['sub_groups']
      else
        self.user_limit = 5
        self.admin_limit = 1
        self.sub_group_limit = 0
      end
    end
  end

  # Updates core fields in stripe if they change locally 
  # (it won't run if this callback is being fired by stripe itself)
  def update_stripe_if_needed
    if !new_record? && (context != 'stripe') && (subscription_plan_changed? \
        || stripe_subscription_card_changed? || name_changed? || url_changed? || website_changed?)
      Group.delay(queue: 'low').update_stripe_subscription(id)
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

  def update_caps_field
    if url_with_caps.nil?
      self.url = nil
    else
      self.url = url_with_caps.downcase
    end
  end

  def new_owner_username_exists
    if new_owner_username.blank?
      true
    else
      new_owner = User.find(new_owner_username) rescue nil
      if new_owner.nil?
        errors.add(:new_owner_username, " is not a valid Badge List username")
        false
      else
        true
      end
    end
  end

  # The only way you can save a private group is if you select a subscription and a card 
  # OR if the subscription has been canceled.
  def subscription_fields_valid
    public? || (subscription_status == 'canceled') \
      || (subscription_plan && stripe_subscription_card)
  end

  def change_owner
    if new_owner_username && new_owner_username_changed?
      new_owner = User.find(new_owner_username) rescue nil
      if new_owner && (owner_id != new_owner.id)
        self.owner = new_owner
        self.admins << new_owner unless self.admin_ids.include? new_owner.id
      end
      self.new_owner_username = nil
    end
  end

end
