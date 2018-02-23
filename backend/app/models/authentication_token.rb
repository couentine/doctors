#==========================================================================================================================================#
# 
# AUTHENTICATION TOKEN MODEL
# 
# To create a new authentication token use `AuthenticationTokenCreationService`.
# 
#==========================================================================================================================================#

class AuthenticationToken
  include Mongoid::Document
  include Mongoid::Timestamps
  
  # === CONSTANTS === #

  BODY_LENGTH = 30
  MONGO_ID_LENGTH = 24 # this is just here for easy reference, it should never change

  # === RELATIONSHIPS === #

  belongs_to :user, inverse_of: :authentication_tokens, class_name: 'User'
  belongs_to :creator, inverse_of: :created_authentication_tokens, class_name: 'User'

  # === FIELDS === #

  field :permission_sets, type: Array, default: []
  field :body,            type: String
  field :last_used_at,    type: Time
  field :ip_address,      type: String
  field :user_agent,      type: String
  field :request_count,   type: Integer, default: 0

  # === VALIDATIONS === #

  validates :user, presence: true

  # === CALLBACK === #

  before_create :generate_body
  before_save :remove_invalid_permission_sets

  # === INSTANCE METHODS === #

  # Returns the user id with the token body appended to it. This is the actual value which is passed to the `token` parameter in the API.
  def value
    if body.present? && user_id.present?
      user_id.to_s + body
    else
      nil
    end
  end

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

  def remove_invalid_permission_sets
    if permission_sets.present?
      permission_sets.each do |permission_set|
        if !ApplicationPolicy::PERMISSION_SETS.keys.include?(permission_set)
          self.permission_sets.delete permission_set
        end
      end
    end
  end

end