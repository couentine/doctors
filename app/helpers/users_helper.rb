module UsersHelper

  # Returns the Gravatar (http://gravatar.com/) for the given user.
  # Accepts options: size, class, username (provide if user account might be deleted)
  def gravatar_for(user, options = { :size => 50, :username => nil })
    size = options[:size]
    img_class = "gravatar"
    username = options[:username] || user.name
    
    if options.has_key?(:class) 
      img_class += " #{options[:class]}" 
    end

    gravatar_url = gravatar_url_for user, :size => size
    image_tag(gravatar_url, alt: username, class: img_class )
  end

  # Same as above but only returns the URL
  # Accepts options: size
  def gravatar_url_for(user, options = { :size => 50 })
    size = options[:size]
    email = (user) ? user.email.downcase : 'nonexistentuser@example.com'
    gravatar_id = Digest::MD5::hexdigest(email)

    "https://secure.gravatar.com/avatar/#{gravatar_id}?s=#{size}&d=mm"
  end

end