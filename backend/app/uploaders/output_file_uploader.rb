# encoding: utf-8

class OutputFileUploader < CarrierWave::Uploader::Base
  # This uploader is used to upload manually created output files
  # Specifically it is used for non-image file types
  
  storage :fog

  def store_dir
    "out/#{model.class.to_s.underscore}/#{model.id}"
  end

  # Add a white list of extensions which are allowed to be uploaded.
  def extension_white_list
    %w(csv)
  end
end
