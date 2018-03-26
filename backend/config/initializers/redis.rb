if ENV["REDISCLOUD_URL"]
  uri = URI.parse(ENV["REDISCLOUD_URL"])
  $redis = Redis.new(:host => uri.host, :port => uri.port, :password => uri.password)
  THROTTLE_REDIS_CLIENT = Redis.new(:host => uri.host, :port => uri.port, :password => uri.password)
else
  THROTTLE_REDIS_CLIENT = Redis.new
end