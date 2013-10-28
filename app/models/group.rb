class Group
  include Mongoid::Document
  include Mongoid::Timestamps

  # === CONSTANTS === #

  MAX_NAME_LENGTH = 50

  # === RELATIONSHIP === #

  has_one :creator, inverse_of: :created_groups, class_name: "User"
  has_and_belongs_to_many :admins, inverse_of: :admin_of, class_name: "User"
  has_and_belongs_to_many :members, inverse_of: :member_of, class_name: "User"

  # === FIELDS & VALIDATIONS === #

  field :name,          :type => String
  field :url,           :type => String
  field :location,      :type => String
  field :website,       :type => String
  field :image_url,     :type => String
  field :type,          :type => String
  field :customer_code, :type => String

  validates :name, presence: true, length: { maximum: MAX_NAME_LENGTH }

end
