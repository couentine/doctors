class Group
  include Mongoid::Document
  include Mongoid::Timestamps

  # === CONSTANTS === #

  MAX_NAME_LENGTH = 50
  MAX_URL_LENGTH = 40
  MAX_LOCATION_LENGTH = 200
  VALID_TYPE_VALUES = ['open', 'closed', 'private']
  VALID_CUSTOMER_CODE_VALUES = ['valid_customer_code', 'kstreem'] # add new customers here

  # === RELATIONSHIPS === #

  belongs_to :creator, inverse_of: :created_groups, class_name: "User"
  has_and_belongs_to_many :admins, inverse_of: :admin_of, class_name: "User"
  has_and_belongs_to_many :members, inverse_of: :member_of, class_name: "User"
  has_many :badges, dependent: :delete

  # === FIELDS & VALIDATIONS === #

  field :name,            :type => String
  field :url,             :type => String
  field :location,        :type => String
  field :website,         :type => String
  field :image_url,       :type => String
  field :type,            :type => String
  field :customer_code,   :type => String
  field :invited_admins,  :type => Array
  field :invited_members, :type => Array

  validates :name, presence: true, length: { within: 3..MAX_NAME_LENGTH }
  validates :url, presence: true, uniqueness: true, length: { within: 3..MAX_URL_LENGTH }, 
            format: { with: /\A[\w-]+\Z/, message: "only allows url-friendly characters" },
            exclusion: { in: APP_CONFIG['blocked_url_slugs'],
                         message: "%{value} is a specially reserved url." }
  validates :location, length: { maximum: MAX_LOCATION_LENGTH }
  validates :website, url: true
  validates :image_url, url: true
  validates :type, inclusion: { in: VALID_TYPE_VALUES, 
                                message: "%{value} is not a valid Group Type" }
  validates :customer_code, presence: { message: "is required for private Groups" }, if: :private?
  validates :customer_code, inclusion: { in: VALID_CUSTOMER_CODE_VALUES, 
            allow_nil: true, message: "%{value} is not a valid customer code" }, if: :private?
  validates :creator, presence: true

  # === CALLBACKS === #

  after_validation :add_creator_to_admins, on: :create
  after_validation :initialize_arrays, on: :create

  # === CLASS METHODS === #

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

  def private?
    type == "private"
  end

  def add_creator_to_admins
    self.admins << self.creator unless self.creator.blank?
  end

  def initialize_arrays
    self.invited_admins ||= []
    self.invited_members ||= []
  end

end
