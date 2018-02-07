class AuthenticationToken
  include Mongoid::Document
  include Mongoid::Timestamps
  
  # === CONSTANTS === #

  BODY_LENGTH = 30
  MONGO_ID_LENGTH = 24 # this is just here for easy reference, it should never change

  # === RELATIONSHIPS === #

  belongs_to :user

  # === FIELDS & VALIDATIONS === #

  field :body,            type: String
  field :last_used_at,    type: Time
  field :ip_address,      type: String
  field :user_agent,      type: String
  field :request_count,   type: Integer, default: 0

  # === CALLBACK === #

  before_create :generate_body

  # === INSTANCE METHODS === #

  # Call this every time the token is used. It accepts an ActionDispatch::Request.
  # Use `track_request!` if you would like to commit the save.
  def track_request(request)
    self.last_used_at = Time.now
    self.ip_address = request.remote_ip
    self.user_agent = request.user_agent
    self.request_count = (request_count || 0) + 1
  end
  
  # Call this every time the token is used. It accepts an ActionDispatch::Request.
  # This version saves the record afterward.
  def track_request!(request)
    track_request(request)
    self.save
  end

  # === PROTECTED METHODS === #

  protected

  def generate_body
    loop do
      self.body = SecureRandom.base64(BODY_LENGTH).first(BODY_LENGTH).tr('+/=', 'BLr'); # BLr = Badge List Rules! :)
      break unless AuthenticationToken.where(body: body).exists?
    end
  end

end