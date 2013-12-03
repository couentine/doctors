module UsersHelper

  # Returns the Gravatar (http://gravatar.com/) for the given user.
  # Accepts options: size, class
  def gravatar_for(user, options = { :size => 50 })
    size = options[:size]
    img_class = "gravatar"
    
    if options.has_key?(:class) 
      img_class += " #{options[:class]}" 
    end

    gravatar_url = gravatar_url_for user, :size => size
    image_tag(gravatar_url, alt: user.name, class: img_class )
  end

  # Same as above but only returns the URL
  # Accepts options: size
  def gravatar_url_for(user, options = { :size => 50 })
    size = options[:size]
    gravatar_id = Digest::MD5::hexdigest(user.email.downcase)

    "https://secure.gravatar.com/avatar/#{gravatar_id}?s=#{size}"
  end

end