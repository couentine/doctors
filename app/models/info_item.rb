class InfoItem
  include Mongoid::Document
  include Mongoid::Timestamps
  
  # === CONSTANTS === #

  TYPE_VALUES = ['stripe.event.invoice.payment_succeeded', 'stripe.event.invoice.payment_failed']

  # === RELATIONSHIPS === #

  belongs_to :user
  belongs_to :group

  # === FIELDS & VALIDATIONS === #

  field :type,        type: String
  field :data,        type: Hash, default: {}, pre_processed: true

  validates :type, inclusion: { in: TYPE_VALUES, message: "%{value} is not a valid type" }

end
