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
  has_and_belongs_to_many :admins, inverse_of: :admin_of, class_name: "User"
  has_and_belongs_to_many :members, inverse_of: :member_of, class_name: "User"
  has_many :badges, dependent: :restrict # You have to delete all the badges FIRST

  # === FIELDS & VALIDATIONS === #

  field :name,                    type: String
  field :url,                     type: String
  field :url_with_caps,           type: String
  field :location,                type: String
  field :website,                 type: String
  field :image_url,               type: String
  field :type,                    type: String, default: 'private'
  field :customer_code,           type: String
  field :validation_threshold,    type: Integer, default: 1
  field :invited_admins,          type: Array, default: []
  field :invited_members,         type: Array, default: []
  field :flags,                   type: Array, default: []

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

  # Which fields are accessible?
  attr_accessible :name, :url_with_caps, :location, :website, :image_url, :type, :customer_code, 
    :validation_threshold

  # === CALLBACKS === #

  before_validation :set_default_values, on: :create
  before_validation :update_caps_field
  before_create :add_creator_to_admins

  # === GROUP MOCK FIELD METHODS === #
  # These are used to mock the presence of certain fields in the JSON output.

  def primary_email; (!creator.nil?) ? creator.email : nil; end
  def issuer_website; (website.blank?) ? "#{APP_CONFIG['root_url']}/#{url}" : website; end

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
    admins.count + members.count
  end

  def has_member?(user)
    members.include?(user)
  end

  def has_admin?(user)
    admins.include?(user)
  end

  def has_invited_member?(email)
    found_user = invited_members.detect { |u| u["email"] == email}
    found_user != nil
  end

  def has_invited_admin?(email)
    found_user = invited_admins.detect { |u| u["email"] == email}
    found_user != nil
  end

protected


  def add_creator_to_admins
    self.admins << self.creator unless self.creator.blank?
  end

  def set_default_values
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

end
