class BadgeMaker

  # === HOW TO LOAD NEW ICONS === #
  #
  # Do this in your dev environment then deploy after done.
  #
  # 1) Download a bunch of the zip files from the noun project.
  # 2) Expand them all so that they are in their own subdirectories (named 'icon_1234')
  # 3) Copy all of the icon folders into NEW_ICONS_INBOX
  # 4) Fire up the rails console and type >> BadgeMaker.process_new_icons
  # 5) Check NEW_ICONS_OUTBOX to see the results and repeat steps as needed.
  #    NOTE: To manually specify name or key add a line to the license.txt file that look like...
  #          name="Manual Icon Name" OR key="manual-icon-key"
  # 6) Copy the icons and index.yaml into the icons directory
  # 7) Fire up the app ($ rails s) and make sure it all works (this will also sort the index.yaml)
  # 8) Deploy to production

  
  # === CONSTANTS === #

  THUMBNAIL_SIZE = 50
  LIB_PATH = "#{Rails.root}/lib/modules"
  IMAGES_ROOT_PATH = "#{Rails.root}/lib/assets/badge_maker"
  THUMBNAILS_ROOT_PATH = "#{Rails.root}/app/assets/images/badge_maker"
  VALID_HEX_COLOR = /\A(\h{3}|\h{6})\z/
  
  NEW_ICONS_INBOX = "#{IMAGES_ROOT_PATH}/inbox"
  NEW_ICONS_OUTBOX = "#{IMAGES_ROOT_PATH}/outbox"
  
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
            'type' => 'public',
            'item_type' => 'frame',
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
            'type' => 'public',
            'item_type' => 'icon',
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
    elsif !color1[VALID_HEX_COLOR]
      color1 = 'FFFFFF'
    end
    if color2.blank?
      random_key = config[:colors]['foreground'].keys.sample
      color2 = config[:colors]['foreground'][random_key]['hex']
    elsif !color2[VALID_HEX_COLOR]
      color2 = '000000'
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

  # Returns a widened version of the image
  def self.build_wide_image(badge_image)
    badge_image.combine_options do |c|
      c.gravity "center"
      c.background "transparent"
      c.extent "1000x500"
    end
    badge_image
  end

  # Returns the attribution hash for the specified type (:frames or :icons) and name
  def self.get_attribution(type, name)
    if !BADGE_MAKER_CONFIG.nil? && BADGE_MAKER_CONFIG[type].include?(name.to_s.downcase)
      BADGE_MAKER_CONFIG[type][name.to_s.downcase]["attribution"]
    else
      nil
    end
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

  def self.process_new_icons
    license_regex = /must be attributed as:\s+(.+)\s+by\s+(.+)\s+from The Noun Project/
    name_regex = /name="(.+)"/
    key_regex = /key="(.+)"/
    
    # Make the folders we'll need
    FileUtils.mkdir_p("#{NEW_ICONS_OUTBOX}/icons") unless File.directory? "#{NEW_ICONS_OUTBOX}/icons"
    FileUtils.mkdir_p("#{NEW_ICONS_OUTBOX}") unless File.directory? "#{NEW_ICONS_OUTBOX}"
    FileUtils.mkdir_p("#{NEW_ICONS_OUTBOX}/success") unless File.directory? "#{NEW_ICONS_OUTBOX}/success"
    FileUtils.mkdir_p("#{NEW_ICONS_OUTBOX}/error") unless File.directory? "#{NEW_ICONS_OUTBOX}/error"
    FileUtils.mkdir_p("#{NEW_ICONS_OUTBOX}/duplicate") unless File.directory? "#{NEW_ICONS_OUTBOX}/duplicate"
    FileUtils.mkdir_p("#{NEW_ICONS_OUTBOX}/public") unless File.directory? "#{NEW_ICONS_OUTBOX}/public"

    icon_folders = Dir["#{NEW_ICONS_INBOX}/*/"]
    key, type, name, author_name, status, result = nil, nil, nil, nil, nil, nil
    icon_image_file, config_row = nil, nil
    org_name, org_url = "The Noun Project", "http://www.thenounproject.com"
    
    updated_icon_index = init[:icons]
    new_icon_index = {}

    icon_folders.sort.each do |icon_folder|
      begin
        icon_image_file = icon_folder + icon_folder.split("/").last + ".png"
        license = File.read("#{icon_folder}license.txt")

        # First load the license information
        if license.include? "This icon is in the Public Domain"
          type = "public"
          if license.include? "name="
            # This is a manually named public domain icon
            result = license.scan(name_regex)
            if result.count == 1
              name = result.first[0].strip
              key = name.parameterize.downcase
              type = "public"
              author_name = nil
              status = :success
            else
              status = :error
            end
          else
            name, key, author_name = nil, nil, nil
            status = :public
          end
        elsif license.include? "must be attributed as:"
          result = license.scan(license_regex)
          if (result.count == 1)
            name = result.first[0].strip
            key = name.parameterize.downcase
            type = "attribution"
            author_name = result.first[1].strip
            status = :success

            # Look for a manually specified key
            if license.include? "key="
              result = license.scan(key_regex)
              key = result.first[0].strip if result.count == 1
            end
          else
            status = :error
          end
        else
          status = :error
        end
        puts "#{icon_folder} >> #{status}:#{key}:#{name}:#{author_name}"

        # Now build the icons if license retrieval was successful
        if status == :success
          if updated_icon_index.include? key
            status = :duplicate
          else
            # Build the image
            icon_image = MiniMagick::Image.open(icon_image_file)
            icon_image.resize "500x500"
            icon_image.write "#{NEW_ICONS_OUTBOX}/icons/#{key}.png"

            # Build the config row
            config_row = { 'attribution' => { 
              'type' => type,
              'item_type' => 'icon',
              'item_name' => name,
              'author_name' => author_name,
              'author_url' => nil,
              'org_name' => org_name,
              'org_url' => org_url
            } }
            updated_icon_index[key] = config_row
            new_icon_index[key] = config_row
          end
        end
      rescue Exception => e
        status = :error
        puts "#{icon_folder} >> ERROR = #{e.message}"
      end

      # Finally we move the original folder
      case status
      when :success
        FileUtils.mv(icon_folder, "#{NEW_ICONS_OUTBOX}/success")
      when :error
        FileUtils.mv(icon_folder, "#{NEW_ICONS_OUTBOX}/error")
      when :duplicate
        FileUtils.mv(icon_folder, "#{NEW_ICONS_OUTBOX}/duplicate")
      when :public
        FileUtils.mv(icon_folder, "#{NEW_ICONS_OUTBOX}/public")
      end
    end

    # The last step is outputing the YAML files
    File.open("#{NEW_ICONS_OUTBOX}/icons/index.yml", 'w') {|f| f.write updated_icon_index.to_yaml }
    File.open("#{NEW_ICONS_OUTBOX}/icons/new_index.yml", 'w') {|f| f.write new_icon_index.to_yaml }
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
