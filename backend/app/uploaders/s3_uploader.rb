# encoding: utf-8

class S3Uploader < CarrierWave::Uploader::Base
  include CarrierWave::MiniMagick

  storage :fog

  def store_dir
    "u/#{model.class.to_s.underscore}/#{model.id}"
  end

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

  # CONTENT TYPE WORKAROUND (http://bit.ly/2yp1z4C) - Needed because carrierwave direct messes up the default content type behavior.
  GENERIC_CONTENT_TYPES = %w[application/octet-stream binary/octet-stream]
  process :clear_generic_content_type
  def clear_generic_content_type
    file.content_type = nil if GENERIC_CONTENT_TYPES.include?(file.try(:content_type))
  end
end
