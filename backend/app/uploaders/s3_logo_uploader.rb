# encoding: utf-8

class S3LogoUploader < CarrierWave::Uploader::Base
  include CarrierWave::MiniMagick
  include CarrierWave::MimeTypes
  storage :fog

  def store_dir
    "u/#{model.class.to_s.underscore}/#{model.id}"
  end

  process :set_content_type
  process :resize_to_fit => [500, 500]

  version :medium do
    process :resize_to_fit => [200, 200]
  end

  version :small do
    process :resize_to_fit => [50, 50]
  end

  # Add a white list of extensions which are allowed to be uploaded.
  def extension_white_list
    %w(png jpg jpeg gif)
  end
end
