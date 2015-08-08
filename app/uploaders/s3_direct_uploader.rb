class S3DirectUploader < CarrierWave::Uploader::Base
  include CarrierWaveDirect::Uploader
  include CarrierWave::MiniMagick
  include ActiveModel::Conversion
  extend ActiveModel::Naming

  # Add a white list of extensions which are allowed to be uploaded.
  def extension_white_list
    %w(png jpg jpeg gif)
  end
end
