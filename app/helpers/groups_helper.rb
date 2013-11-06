module GroupsHelper

  def group_image_tag_for(group, options = { :size => 'large' })
    size = 200;

    if group.image_url && !group.image_url.empty?
      image_tag(group.image_url, size: size, class: "group-image group-image-#{options[:size]}", alt: "Learning Group Image")
    else
      image_tag('group-image-default.png', size: size, class: "group-image group-image-#{options[:size]}", alt: "Learning Group Image")
    end
  end

end
