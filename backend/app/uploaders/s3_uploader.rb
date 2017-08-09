# encoding: utf-8

class S3Uploader < CarrierWave::Uploader::Base
  include CarrierWave::MiniMagick
  include CarrierWave::MimeTypes
  storage :fog

  def store_dir
    "u/#{model.class.to_s.underscore}/#{model.id}"
  end

  process :set_content_type

  version :thumb do
    process :resize_to_fit => [50, 50]
  end
  
  version :preview do 
    process :resize_to_fit => [700, 700]
  end
  
  version :full do 
    process :resize_to_fit => [2048, 2048]
  end

  # Add a white list of extensions which are allowed to be uploaded.
  def extension_white_list
    %w(png jpg jpeg gif)
  end
end
