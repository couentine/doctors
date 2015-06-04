class InfoItem
  include Mongoid::Document
  include Mongoid::Timestamps
  
  # === CONSTANTS === #

  TYPE_VALUES = ['open', 'closed', 'private']

  # === RELATIONSHIPS === #

  belongs_to :user
  belongs_to :group

  # === FIELDS & VALIDATIONS === #

  field :type,        type: String
  field :data,        type: String

  validates :type, inclusion: { in: TYPE_VALUES, message: "%{value} is not a valid type" }

end
