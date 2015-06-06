class Poller
  include Mongoid::Document
  include Mongoid::Timestamps
  
  # === CONSTANTS === #

  STATUS_VALUES = ['pending', 'successful', 'failed']

  POLLING_INTERVAL = 150 # in milliseconds
  DELETE_AFTER = 5.minutes # old pollers are automatically deleted after they complete

  # === FIELDS & VALIDATIONS === #

  field :status,        type: String, default: 'pending'
  field :completed,        type: Boolean, default: false
  field :message,       type: String
  
  validates :status, inclusion: { in: STATUS_VALUES, message: "%{value} is not a valid status" }
  
  # === CALLBACK === #

  before_save :set_completed_if_needed
  after_save :queue_delete_if_completed

protected
  
  def set_completed_if_needed
    if !completed && ((status == 'successful') || (status == 'failed'))
      self.completed = true
    end
  end

  def queue_delete_if_completed
    self.delay_for(DELETE_AFTER).delete if completed
  end

end
