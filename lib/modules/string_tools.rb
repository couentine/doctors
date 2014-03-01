module StringTools

  # === CONSTANTS === #
  HTTP_URL_REGEX = /\b(img:)?https?:\/\/[^\s<]+\b/
  NON_HTTP_URL_REGEX = /\b[a-z]{3}\.[^\s<]+\b/
  IMG_REGEX = /(?:png|jpe?g|gif|svg)$|^img:/i
  HASHTAG_REGEX = /#[\w-]+/
  SECTION_DIVIDER_REGEX = /-+\s*<br *\/?>\s*/i
  
  LINKS_TO_TRANSLATE = [
    [/youtube.com.*(?:\/|v=)([^&$]+)/,
      "<a href='https://www.youtube.com/watch?v={id}' class='linkified-video youtube' target='_blank'>
        <img src='http://img.youtube.com/vi/{id}/0.jpg'>
      </a>"]
  ]

  # Replaces links and hashtags with valid anchor tags
  # Also replace links that end with image extensions into image tags
  # "http://google.com" => "<a href='http://google.com' target='_blank'>http://google.com</a>"
  # "#hash-tag" => "<a href='/group-url/badge-url/hash-tag'>#hash-tag</a>"
  # "http://example.com/image.png" => "<img src='http://example.com/image.png'/>"
  # Returns a hash = { :text => linkified_text, :tags => [list_of_downcased_tags],
  #                    :tags_with_caps => [list_of_tags_as_typed] }
  def linkify_text(text, group, badge)
    if text.blank?
      { text: '', tags: [], tags_with_caps: [] }
    else
      tags, tags_with_caps = [], []
      new_text = text.gsub(HASHTAG_REGEX) do |tag| 
        stripped_tag = tag[1..tag.length]
        unless tags.include? stripped_tag.downcase
          tags << stripped_tag.downcase 
          tags_with_caps << stripped_tag
        end
        "<a class='linkified-tag' href='/#{group.url}/#{badge.url}/#{stripped_tag}'>#{tag}</a>"
      end.gsub(HTTP_URL_REGEX) { |url| make_tag_for url }
      # Removing this for now... it double tags some things
      # .gsub(NON_HTTP_URL_REGEX) { |url| make_tag_for "http://#{url}" }

      { text: new_text, tags: tags, tags_with_caps: tags_with_caps }
    end
  end

  def make_tag_for(url)
    found_one = false
    the_id = nil
    return_text = nil

    LINKS_TO_TRANSLATE.each do |link_pair|
      if the_id.nil?
        if url[link_pair.first]
          the_id = url.match(link_pair.first)[1]
          return_text = link_pair.last.gsub(/\{id\}/, the_id)
        end
      end
    end

    logger.debug "+++make_tag_for: url=#{url}, the_id=#{the_id.inspect}, return_text=#{return_text}+++"

    if the_id.nil?
      if url[IMG_REGEX]
        stripped_url = url.sub(/^img:/i, '')
        return_text = "<a class='linkified-image' href='#{stripped_url}' target='_blank'><img src='#{stripped_url}'/></a>"
      else
        return_text= "<a class='linkified-url' href='#{url}' target='_blank'>#{url}</a>"
      end
    end

    return_text
  end

  # Turns a topic display name into a tag by removing special characters and spaces
  # Example: "Example Topic! Name" -> "Example-Topic-Name"
  def tagify_string(topic_display_name)
    if topic_display_name.nil?
      nil
    else
      topic_display_name.strip\
        .gsub(/\./, '').gsub(/[^ A-Za-z0-9]/, ' ').gsub(/ {2,}/, ' ').strip.gsub(/ /, '-')
    end
  end

end