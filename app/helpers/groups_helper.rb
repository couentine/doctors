module GroupsHelper

  def group_image_tag_for(group, size = nil)
    if group.image_url && !group.image_url.empty?
      image_tag(group.image_url, size: size, class: "group-image", alt: "Learning Group Image")
    else
      image_tag('group-image-default.png', size: size, class: "group-image", alt: "Learning Group Image")
    end
  end

  def group_image_url_for(group)
    if group.image_url && !group.image_url.empty?
      group.image_url
    else
      image_path('group-image-default.png')
    end
  end

end
