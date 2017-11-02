class S3FileUploader < CarrierWave::Uploader::Base
  storage :fog
  
  def store_dir
    "u/#{model.class.to_s.underscore}/#{model.id}"
  end

  # CONTENT TYPE WORKAROUND (http://bit.ly/2yp1z4C) - Needed because carrierwave direct messes up the default content type behavior.
  GENERIC_CONTENT_TYPES = %w[application/octet-stream binary/octet-stream]
  process :clear_generic_content_type
  def clear_generic_content_type
    file.content_type = nil if GENERIC_CONTENT_TYPES.include?(file.try(:content_type))
  end
end
