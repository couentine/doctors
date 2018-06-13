# encoding: utf-8

class S3BadgeUploader < CarrierWave::Uploader::Base
  include CarrierWave::MiniMagick
  
  storage :fog
  
  def store_dir
    "u/#{model.class.to_s.underscore}/#{model.id}/#{mounted_as}"
  end

  def filename
    if original_filename
      if model && model.read_attribute(mounted_as).present?
        model.read_attribute(mounted_as)
      else
        # preferred standard filename
        "#{model.class.to_s.underscore}.png"
      end
    end
  end

  # Process files as they are uploaded:
  process :resize_to_limit => [500, 500]

  version :medium do
    process :resize_to_limit => [200, 200]
  end

  version :small do
    process :resize_to_limit => [50, 50]
  end

  version :wide do 
    process :widen_image
  end

  # Add a white list of extensions which are allowed to be uploaded.
  def extension_white_list
    %w(png)
  end

  def widen_image
    manipulate! do |img|
      img = BadgeMaker.build_wide_image(img)
    end
  end

  # NOTE: This is a hack to clear out the filenames because I was having issues changing the image
  #       For more info refer to: https://github.com/carrierwaveuploader/carrierwave/issues/401
  def clear_uploader
    @file = @filename = @original_filename = @cache_id = @version = @storage = nil
    model.send(:write_attribute, mounted_as, nil)
  end

  # CONTENT TYPE WORKAROUND (http://bit.ly/2yp1z4C) - Needed because carrierwave direct messes up the default content type behavior.
  GENERIC_CONTENT_TYPES = %w[application/octet-stream binary/octet-stream]
  process :clear_generic_content_type
  def clear_generic_content_type
    file.content_type = nil if GENERIC_CONTENT_TYPES.include?(file.try(:content_type))
  end
end
