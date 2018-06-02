#==========================================================================================================================================#
# 
# THROTTLE DAILY WITH CLIENT ID
# 
# This extends the default rack throttle class and adds a client id that is based on the session id or the json token, then falls back
# to the ip address only as a last resort.
# 
#==========================================================================================================================================#

require 'digest'

# This is used to extract the token from the json request body if needed (via the `token` match group)
BODY_TOKEN_REGEX = /"token":\s*"(?<token>[^"]+)"/

class Rack::Throttle::DailyWithClientId < Rack::Throttle::Daily

  # If changing this, change it in the other middleware files in this folder (yes, not very DRY)
  def client_identifier(request)
    unique_id = nil

    # Attempt to get a unique id that is better than the ip address
    if request.session.present?
      unique_id = request.session.id
    elsif request.headers['token'].present?
      unique_id = request.headers['token']
    elsif request.params['token'].present?
      unique_id = request.params['token']
    elsif (request.content_type == 'application/json') && request.body.present?
      unique_id = request.body.read[BODY_TOKEN_REGEX, 'token']
    end

    if unique_id.present?
      # If we were successful, then hash the unique id so we don't store it in redis
      unique_id = Digest::MD5.new.base64digest(unique_id).tr('+/=', 'eta')
    else
      unique_id = request.ip.to_s
    end

    return "throttle.#{unique_id}"
  end

end