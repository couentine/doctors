#==========================================================================================================================================#
# 
# THROTTLE CACHE
# 
# This is used by the rack-throttle powered rate limiting functionality declared in `application.rb`.
# The purpose of the custom cache library is to set an expiration time on the cache entries. 
# The expiration time is by matching the keys to the regexes in EXPIRATION_MAP.
# 
#==========================================================================================================================================#

# If the cache key matches one of the regex keys in the has below, then the corresponding value is used as the expiration time (in seconds)
# If no match is found, DEFAULT_EXPIRATION is used instead
EXPIRATION_MAP = {
    /^[\w\.]+:\d{4}-\d{2}-\d{2}$/ => 1.day.to_i # matches daily throttle keys
}
DEFAULT_EXPIRATION = 60 # seconds

class ThrottleCache
  def set(key, value)
    THROTTLE_REDIS_CLIENT.set(key, value)
    
    duration = EXPIRATION_MAP[EXPIRATION_MAP.keys.find{ |re| re =~ key }] || DEFAULT_EXPIRATION
    THROTTLE_REDIS_CLIENT.expire(key, duration)
  end

  def get(key)
    THROTTLE_REDIS_CLIENT.get(key)
  end
end