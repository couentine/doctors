class InfoItem
  include Mongoid::Document
  include Mongoid::Timestamps
  
  # === CONSTANTS === #

  TYPE_VALUES = ['stripe-event', 'dev-log']

  # === RELATIONSHIPS === #

  belongs_to :user
  belongs_to :group

  # === FIELDS & VALIDATIONS === #

  field :type,        type: String
  field :name,        type: String # optional, acts as a label
  field :key,         type: String # optional, must be unique
  field :data,        type: Hash, default: {}, pre_processed: true

  validates :type, inclusion: { in: TYPE_VALUES, message: "%{value} is not a valid type" }
  validates :key, uniqueness: { scope: :type }, allow_blank: true

end
