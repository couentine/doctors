class S3DirectFileUploader < CarrierWave::Uploader::Base
  include CarrierWaveDirect::Uploader
  include ActiveModel::Conversion
  extend ActiveModel::Naming
end
