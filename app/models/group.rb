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
  field :monthly_active_users,        type: Hash, default: {}, pre_processed: true
  field :active_user_count,           type: Integer
  field :user_limit,                  type: Integer, default: 5 # only for private groups
  field :new_owner_username,          type: String
  
  field :subscription_plan,           type: String # values are defined in config.yml
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
  validates :subscription_plan, presence: true, if: :private?

  validate :new_owner_username_exists
  validate :owner_has_stripe_card?, if: :private?

  # Which fields are accessible?
  attr_accessible :name, :url_with_caps, :location, :website, :image_url, :type, :customer_code, 
    :validation_threshold, :user_limit, :new_owner_username, :subscription_plan

  # === CALLBACKS === #

  before_validation :set_default_values, on: :create
  before_validation :update_caps_field
  before_create :add_creator_to_admins
  before_update :change_owner
  after_create :queue_create_stripe_subscription

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

  # Validation method to confirm that the group owner has added credit cards
  def owner_has_stripe_card?
    if owner_id.blank?
      false
    else
      owner.has_stripe_card?
    end
  end

  # Calls out to stripe to create a new subscription for this group on the owner's customer record
  def create_stripe_subscription
    if !subscription_plan.blank? && stripe_subscription_id.blank? && owner_has_stripe_card?
      Stripe.api_key = ENV['stripe_secret_key']

      customer = Stripe::Customer.retrieve(owner.stripe_customer_id)
      subscription = customer.subscriptions.create(
        plan: subscription_plan,
        metadata: {
          description: "#{name} (#{url})",
          group_id: id,
          group_url: url,
          group_name: name,
          group_website: website
        }
      ) if customer
      
      if customer && subscription
        self.stripe_subscription_id = subscription.id
        self.stripe_subscription_status = subscription.status
        self.stripe_subscription_details = subscription.to_hash
        self.save
      end
    end
  end

  # Call this from after_create callback
  def queue_create_stripe_subscription
    if !subscription_plan.blank? && stripe_subscription_id.blank? && owner_has_stripe_card?
      self.delay(queue: 'high').create_stripe_subscription
    end
  end

  # Calls out to stripe to refresh the subscription status
  def refresh_stripe_subscription
    if !stripe_subscription_id.blank? && !owner.stripe_customer_id.blank?
      Stripe.api_key = ENV['stripe_secret_key']

      customer = Stripe::Customer.retrieve(owner.stripe_customer_id)
      subscription = customer.subscriptions.retrieve(stripe_subscription_id) if customer
      
      if customer && subscription
        self.stripe_subscription_status = subscription.status
        self.stripe_subscription_details = subscription.to_hash
        self.save
      end
    end
  end

  # LEFT OFF HERE: Next step... add "queue_refresh_stripe_subscription"
  #   It should take a param that lets me schedule it for later so I can basically have it check
  #   in with the server after each billing event.
  # Then: Work on some functions to propogate changes in the name and url back to the server
  #       Along with a function to cancel the subscription when the owner changes 
  #       ... think it through since i might have to poke holes in the validations

protected

  def add_creator_to_admins
    self.admins << self.creator unless self.creator.blank?
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
