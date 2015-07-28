# encoding: utf-8

class S3BadgeUploader < CarrierWave::Uploader::Base

  include CarrierWave::MiniMagick

  storage :fog
  
  def store_dir
    "u/#{model.class.to_s.underscore}/#{mounted_as}/#{model.id}"
  end

  # Process files as they are uploaded:
  process :resize_to_limit => [500, 500]

  version :medium do
    process :resize_to_limit => [200, 200]
  end

  version :small do
    process :resize_to_limit => [50, 50]
  end

  version :wide do 
    process :widen_image
  end

  # Add a white list of extensions which are allowed to be uploaded.
  def extension_white_list
    %w(png)
  end

  def widen_image
    manipulate! do |img|
      img = BadgeMaker.build_wide_image(img)
    end
  end

end
