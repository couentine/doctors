CarrierWave.configure do |config|
  config.fog_credentials = {
    # Configuration for Amazon S3
    :provider              => 'AWS',
    :aws_access_key_id     => ENV['s3_key'],
    :aws_secret_access_key => ENV['s3_secret'],
    :region                => ENV['s3_region']
  }
 
  # config.cache_dir = "#{Rails.root}/tmp/uploads"    # To let CarrierWave work on heroku
 
  config.fog_directory    = ENV['s3_bucket_name']
end