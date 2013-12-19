module StringTools

  # === CONSTANTS === #
  HTTP_URL_REGEX = /\b(img:)?https?:\/\/[^\s<]+\b/
  NON_HTTP_URL_REGEX = /\b[a-z]{3}\.[^\s<]+\b/
  IMG_REGEX = /(?:png|jpe?g|gif|svg)$|^img:/i
  HASHTAG_REGEX = /#[\w-]+/

  # Replaces links and hashtags with valid anchor tags
  # Also replace links that end with image extensions into image tags
  # "http://google.com" => "<a href='http://google.com' target='_blank'>http://google.com</a>"
  # "#hash-tag" => "<a href='/group-url/badge-url/hash-tag'>#hash-tag</a>"
  # "http://example.com/image.png" => "<img src='http://example.com/image.png'/>"
  def linkify_text(text, group, badge)
    if text.blank?
      ""
    else
      text.gsub(HASHTAG_REGEX) { |tag| "<a href='/#{group.url}/#{badge.url}/#{tag[1..tag.length]}'>#{tag}</a>" }
      .gsub(HTTP_URL_REGEX) { |url| make_tag_for url }
      # Removing this for now... it double tags some things
      # .gsub(NON_HTTP_URL_REGEX) { |url| make_tag_for "http://#{url}" }
    end
  end

  def make_tag_for(url)
    if url[IMG_REGEX]
      stripped_url = url.sub(/^img:/i, '')
      "<a href='#{stripped_url}' target='_blank'><img src='#{stripped_url}'/></a>"
    else
      "<a href='#{url}' target='_blank'>#{url}</a>"
    end
  end

end