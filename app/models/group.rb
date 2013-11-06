class Group
  include Mongoid::Document
  include Mongoid::Timestamps

  # === CONSTANTS === #

  MAX_NAME_LENGTH = 50
  MAX_URL_LENGTH = 40
  MAX_LOCATION_LENGTH = 200
  VALID_TYPE_VALUES = ['open', 'closed', 'private']
  VALID_CUSTOMER_CODE_VALUES = ['valid_customer_code', 'kstreem'] # add new customers here

  # === RELATIONSHIP === #

  belongs_to :creator, inverse_of: :created_groups, class_name: "User", 
             dependent: :nullify
  has_and_belongs_to_many :admins, inverse_of: :admin_of, class_name: "User"
  has_and_belongs_to_many :members, inverse_of: :member_of, class_name: "User"

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
             format: { with: /\A[\w-]+\Z/, message: "only allows url-friendly characters" }
  validates :location, length: { maximum: MAX_LOCATION_LENGTH }
  validates :website, url: true
  validates :image_url, url: true
  validates :type, inclusion: { in: VALID_TYPE_VALUES, 
                                message: "%{value} is not a valid Group Type" }
  validates :customer_code, presence: { message: "is required for private Groups" }, if: :private?
  validates :customer_code, inclusion: { in: VALID_CUSTOMER_CODE_VALUES, 
            allow_nil: true, message: "%{value} is not a valid customer code" }, if: :private?
  validates :creator, presence: true
  validate :url_is_not_a_route

  # === CALLBACKS === #

  after_validation :add_creator_to_admins, on: :create

  # === GROUP FUNCTIONS === #

  def has_member?(user)
    members.include?(user)
  end

  def has_admin?(user)
    admins.include?(user)
  end

  protected

    def url_is_not_a_route
      path = Rails.application.routes.recognize_path("/#{url}", :method => :get) rescue nil
      errors.add(:url, "conflicts with existing path (/#{url})") if path && !path[:url]
    end

    def private?
      type == "private"
    end

    def add_creator_to_admins
      self.admins << self.creator unless self.creator.blank?
    end

end
