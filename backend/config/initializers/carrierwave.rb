CarrierWave.configure do |config|
  
  # Skipping this if we're running in a context where foreman doesn't work
  if ENV['s3_key'] && ENV['s3_secret'] && ENV['s3_region']
    config.fog_credentials = {
      # Configuration for Amazon S3
      :provider              => 'AWS',
      :aws_access_key_id     => ENV['s3_key'],
      :aws_secret_access_key => ENV['s3_secret'],
      :region                => ENV['s3_region']
    }
  end
 
  config.fog_directory    = ENV['s3_bucket_name']
  config.max_file_size     = 50.megabytes 
  
end