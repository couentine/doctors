# encoding: utf-8

class S3Uploader < CarrierWave::Uploader::Base
  include CarrierWave::MiniMagick
  storage :fog

  def store_dir
    "uploads/#{model.class.to_s.underscore}/#{mounted_as}/#{model.id}"
  end

  version :thumb do
    process :resize_to_fit => [50, 50]
  end
  
  version :preview do 
    process :resize_to_fit => [300, 300]
  end
  
  version :full do 
    process :resize_to_fit => [2048, 2048]
  end

  # Add a white list of extensions which are allowed to be uploaded.
  def extension_white_list
    %w(png jpg jpeg gif)
  end
end
