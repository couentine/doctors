# encoding: utf-8

class ImageUploader < CarrierWave::Uploader::Base

  include CarrierWave::MiniMagick

  storage :grid_fs
  
  def store_dir
    "uploads/#{model.class.to_s.underscore}/#{mounted_as}/#{model.id}"
  end

  # Process files as they are uploaded:
  process :resize_to_limit => [500, 500]

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
