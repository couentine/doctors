class BadgeMaker

  # === CONSTANTS === #

  THUMBNAIL_SIZE = 50
  LIB_PATH = "#{Rails.root}/lib/modules"
  IMAGES_ROOT_PATH = "#{Rails.root}/lib/assets/badge_maker"
  THUMBNAILS_ROOT_PATH = "#{Rails.root}/app/assets/images/badge_maker"
  
  # === CLASS METHODS === #

  # Returns hash containing BadgeMaker settings
  def self.init
    # First check if our folders exist and create them if they don't
    FileUtils.mkdir_p("#{IMAGES_ROOT_PATH}/frames") unless File.directory? "#{IMAGES_ROOT_PATH}/frames"
    FileUtils.mkdir_p("#{IMAGES_ROOT_PATH}/icons") unless File.directory? "#{IMAGES_ROOT_PATH}/icons"
    FileUtils.mkdir_p("#{THUMBNAILS_ROOT_PATH}/frames") unless File.directory? "#{THUMBNAILS_ROOT_PATH}/frames"
    FileUtils.mkdir_p("#{THUMBNAILS_ROOT_PATH}/icons") unless File.directory? "#{THUMBNAILS_ROOT_PATH}/icons"

    # Load YAMLs and images
    bm_config = YAML.load_file("#{LIB_PATH}/badge_maker.yml") rescue {}
    frame_index_changed = false
    icon_index_changed = false
    frame_index = YAML.load_file("#{IMAGES_ROOT_PATH}/frames/index.yml") rescue {}
    icon_index = YAML.load_file("#{IMAGES_ROOT_PATH}/icons/index.yml") rescue {}
    frame_images = Dir["#{IMAGES_ROOT_PATH}/frames/*.png"].map do |path| 
      Pathname.new(path).basename.to_s.split(".").first.downcase
    end
    icon_images = Dir["#{IMAGES_ROOT_PATH}/icons/*.png"].map do |path| 
      Pathname.new(path).basename.to_s.split(".").first.downcase
    end
    frame_thumbnails = Dir["#{THUMBNAILS_ROOT_PATH}/frames/*.png"].map do |path| 
      Pathname.new(path).basename.to_s.split(".").first.downcase
    end
    icon_thumbnails = Dir["#{THUMBNAILS_ROOT_PATH}/icons/*.png"].map do |path| 
      Pathname.new(path).basename.to_s.split(".").first.downcase
    end

    # Run through and build out the YAML and thumbnails for new items
    frame_images.each do |image_name|
      unless frame_index.include? image_name
        frame_index_changed = true
        frame_index[image_name] = {
          'inner_width' => 300,
          'offset_x' => 0,
          'offset_y' => 0,
          'attribution' => {
            'item_name' => nil,
            'author_name' => nil,
            'author_url' => nil,
            'org_name' => nil,
            'org_url' => nil
          }
        }
      end

      unless frame_thumbnails.include? image_name
        image = MiniMagick::Image.open("#{IMAGES_ROOT_PATH}/frames/#{image_name}.png")
        image.resize "#{THUMBNAIL_SIZE}x#{THUMBNAIL_SIZE}"
        image.write "#{THUMBNAILS_ROOT_PATH}/frames/#{image_name}.png"
      end
    end
    icon_images.each do |image_name|
      unless icon_index.include? image_name
        icon_index_changed = true
        icon_index[image_name] = {
          'attribution' => {
            'item_name' => nil,
            'author_name' => nil,
            'author_url' => nil,
            'org_name' => nil,
            'org_url' => nil
          }
        }
      end

      unless icon_thumbnails.include? image_name
        image = MiniMagick::Image.open("#{IMAGES_ROOT_PATH}/icons/#{image_name}.png")
        image.resize "#{THUMBNAIL_SIZE}x#{THUMBNAIL_SIZE}"
        image.write "#{THUMBNAILS_ROOT_PATH}/icons/#{image_name}.png"
      end
    end

    # Now output the YAML files if changed
    if frame_index_changed
      File.open("#{IMAGES_ROOT_PATH}/frames/index.yml", 'w') {|f| f.write frame_index.to_yaml }
    end
    if icon_index_changed
      File.open("#{IMAGES_ROOT_PATH}/icons/index.yml", 'w') {|f| f.write icon_index.to_yaml }
    end

    # Return
    { frames: frame_index, icons: icon_index, colors: bm_config['colors'] }
  end

  def self.build_image(frame = nil, icon = nil, color1 = nil, color2 = nil, config = nil)
    config = BADGE_MAKER_CONFIG if config.nil?
    raise "Badge Maker config is missing." if config.nil?
    frame_index = config[:frames]
    icon_index = config[:icons]

    # First randomly set any parameters that are missing
    frame = frame.downcase unless frame.nil?
    frame = frame_index.keys.sample if frame.nil? or !frame_index.include?(frame)
    icon = icon_index.keys.sample if icon.nil? # NOTE: If this is missing we'll build a text icon
    if color1.blank?
      random_key = config[:colors]['background'].keys.sample
      color1 = config[:colors]['background'][random_key]['hex']
    end
    if color2.blank?
      random_key = config[:colors]['foreground'].keys.sample
      color2 = config[:colors]['foreground'][random_key]['hex']
    end

    # Grab the other variables from the index
    inner_width = frame_index[frame]['inner_width']
    offset_x = frame_index[frame]['offset_x']
    offset_y = frame_index[frame]['offset_y']
    center = "#{250+offset_x},#{250+offset_y}"
    if (offset_x == 0) && (offset_y == 0)
      geometry = nil
    else
      x_text = (offset_x < 0) ? "#{offset_x}" : "+#{offset_x}"
      y_text = (offset_y < 0) ? "#{offset_y}" : "+#{offset_y}"
      geometry = "#{x_text}#{y_text}"
    end

    # Then build the badge image
    
    # Start the badge off by cloning the frame and filling in the background color
    badge_image = MiniMagick::Image.open("#{IMAGES_ROOT_PATH}/frames/#{frame}.png")
    badge_image.combine_options do |c|
      c.resize "500x500"
      c.fill "##{color1}"
      c.fuzz "60%"
      c.opaque "white"
    end

    # Then build a foreground mask by adding the icon to the frame
    frame_image = MiniMagick::Image.open("#{IMAGES_ROOT_PATH}/frames/#{frame}.png")
    frame_image.resize "500x500"
    if icon_index.include?(icon.downcase) # then this will have an IMAGE ICON
      icon_image = MiniMagick::Image.open("#{IMAGES_ROOT_PATH}/icons/#{icon}.png")
      icon_image.combine_options do |c|
        c.trim
        c.resize "#{inner_width}x#{inner_width}"
      end
    else # this will have a TEXT ICON
      icon_image = MiniMagick::Image.open("#{IMAGES_ROOT_PATH}/blank.png")
      icon_image.combine_options do |c|
        c.font "#{Rails.root}/app/assets/images/fonts/arialbd.ttf"
        c.gravity "center"
        c.pointsize '240'
        c.draw "text 0,0 '#{icon[0..1]}'"
        c.fill("black")
        c.trim
        c.resize "#{inner_width}x#{inner_width}"
      end
    end
    foreground_mask = frame_image.composite(icon_image) do |c|
      c.gravity "center"
      c.geometry geometry unless geometry.nil?
    end

    # Build out color overlay (By basing it on the frame we ensure that the transparency is kept)
    color2_overlay = MiniMagick::Image.open("#{IMAGES_ROOT_PATH}/frames/#{frame}.png")
    color2_overlay.combine_options do |c|
      c.fill "##{color2}"
      c.fuzz "100%" # basically this will fill all non-transparent pixels
      c.opaque "white"
    end
    color2_overlay.combine_options do |c| # do it again with black to get the straggling pixels
      c.fill "##{color2}"
      c.fuzz "100%"
      c.opaque "black"
    end

    # Finally use the foreground_mask to apply the color overlay to the existing badge_image
    composite_with_mask(badge_image, color2_overlay, foreground_mask)
  end

  def self.test
    config = self.init
    
    letters = [('a'..'z'), ('A'..'Z')].map{|i| i.to_a}.flatten
    config[:frames].keys.each do |frame|
      1.times do |i|
        image = self.build_image nil, letters.sample(2).join, nil, nil, config
        image.write "#{IMAGES_ROOT_PATH}/#{frame}-#{i}.png"
      end
    end
  end

private

  def self.composite_with_mask(source_image, overlay_image, mask_image, output_extension = 'png', &block)
    begin
      second_tempfile = Tempfile.new(output_extension)
      second_tempfile.binmode
    ensure
      second_tempfile.close
    end

    command = MiniMagick::CommandBuilder.new("composite")
    block.call(command) if block
    command.push(source_image.path)
    command.push(overlay_image.path)
    command.push(mask_image.path)
    command.push(second_tempfile.path)

    source_image.run(command)
    return MiniMagick::Image.new(second_tempfile.path, second_tempfile)
  end

end
