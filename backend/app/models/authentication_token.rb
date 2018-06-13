#==========================================================================================================================================#
# 
# AUTHENTICATION TOKEN MODEL
# 
# When creating a new authentication token, always use `AuthenticationTokenValidationService` before saving.
# 
#==========================================================================================================================================#

class AuthenticationToken
  include Mongoid::Document
  include Mongoid::Timestamps
  
  # === CONSTANTS === #

  BODY_LENGTH = 30
  MONGO_ID_LENGTH = 24 # this is just here for easy reference, it should never change
  MAX_NAME_LENGTH = 50

  # === RELATIONSHIPS === #

  belongs_to :user, inverse_of: :authentication_tokens, class_name: 'User'
  belongs_to :creator, inverse_of: :created_authentication_tokens, class_name: 'User'

  # === FIELDS === #

  field :name,           type: String

  field :permissions,     type: Array, default: []
  field :body,            type: String
  field :last_used_at,    type: Time
  field :ip_address,      type: String
  field :user_agent,      type: String
  field :request_count,   type: Integer, default: 0

  # === VALIDATIONS === #

  validates :user, presence: true
  validates :name, length: { maximum: MAX_NAME_LENGTH }

  # === CALLBACK === #

  validate :no_reparenting
  before_create :generate_body
  before_save :clean_permissions

  # === CLASS METHODS === #

  def self.find(token_identifier, suppress_warning: false)
    authentication_token = super(token_identifier) rescue nil

    if authentication_token.nil? && (token_identifier.to_s.length == (24 + BODY_LENGTH))
      if suppress_warning
        authentication_token = AuthenticationToken.where(body: token_identifier.last(BODY_LENGTH)).first
      else
        raise ArgumentError.new('WARNING: Searching for tokens in production is susceptible to to timing attacks. ' \
          'To suppress this warning add `suppress_warning: true`.')
      end
    end

    return authentication_token
  end

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

  def no_reparenting
    if persisted? && user_id_changed? && user_id.present?
      errors.add(:user_id, 'cannot be changed after the token is created')
    end
  end

  def generate_body
    loop do
      self.body = SecureRandom.base64(BODY_LENGTH).first(BODY_LENGTH).tr('+/=', 'BLr'); # BLr = Badge List Rules! :)
      break unless AuthenticationToken.where(body: body).exists?
    end
  end

  # Forces the inclusion of the `mandatory` permission sets. Removes any invalid permission sets.
  def clean_permissions
    self.permissions = ApplicationPolicy::API_PERMISSIONS.select do |permission, settings| 
      settings[:mandatory]
    end.keys + permissions
    self.permissions.uniq!

    if permissions.present?
      permissions.each do |permission|
        if !ApplicationPolicy::API_PERMISSIONS.has_key?(permission)
          self.permissions.delete permission
        end
      end
    end
  end

end