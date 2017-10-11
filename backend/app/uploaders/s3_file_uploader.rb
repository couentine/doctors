class S3FileUploader < CarrierWave::Uploader::Base
  include CarrierWave::MimeTypes

  storage :fog

  process :set_content_type
  
  def store_dir
    "u/#{model.class.to_s.underscore}/#{model.id}"
  end
end
