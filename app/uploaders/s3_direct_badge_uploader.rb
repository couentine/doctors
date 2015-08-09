class S3DirectBadgeUploader < CarrierWave::Uploader::Base
  include CarrierWaveDirect::Uploader
  include CarrierWave::MiniMagick
  include ActiveModel::Conversion
  extend ActiveModel::Naming

  # Add a white list of extensions which are allowed to be uploaded.
  # NOTE: This is the only difference between the normal direct uploader and the badge one.
  def extension_white_list
    %w(png)
  end
end
