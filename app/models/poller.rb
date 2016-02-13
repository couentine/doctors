class Poller
  include Mongoid::Document
  include Mongoid::Timestamps
  
  # === CONSTANTS === #

  STATUS_VALUES = ['pending', 'successful', 'failed']

  # NOTE: If you change any of these values, you'll also need to manually change the constants in
  #       badge_list.js.erb, just above the startPoller() function.
  INITIAL_POLLING_INTERVAL = 150 # in milliseconds
  POLLING_INTERVAL_DOUBLE_RATE = 2 # the polling rate will double every X tries
  POLLING_MAX_TRIES = 13 # given 150 & 2 this will yield a last try at around 28.5 seconds
  DELETE_AFTER = 2.minutes # old pollers are automatically deleted after they complete

  # === FIELDS & VALIDATIONS === #

  field :status,            type: String, default: 'pending'
  field :completed,         type: Boolean, default: false
  field :message,           type: String
  field :waiting_message,   type: String
  field :redirect_to,       type: String
  field :data,              type: Hash
  field :progress,          type: Integer # set 0 to 100 or leave nil
  
  validates :status, inclusion: { in: STATUS_VALUES, message: "%{value} is not a valid status" }
  
  # === CALLBACK === #

  before_save :set_completed_if_needed
  after_save :queue_delete_if_completed
  
  # === CLASS METHODS === #

  def self.delete_poller(poller_id)
    poller = Poller.find(poller_id) rescue nil
    poller.delete if poller
  end

protected
  
  def set_completed_if_needed
    if !completed && ((status == 'successful') || (status == 'failed'))
      self.completed = true
    end
  end

  def queue_delete_if_completed
    Poller.delay_for(DELETE_AFTER).delete_poller(id.to_s) if completed
  end

end
