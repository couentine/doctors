module ApplicationHelper

  # Returns the full title on a per-page basis.
  def full_title(page_title)
    base_title = "Badge List"
    if page_title.empty?
      base_title
    else
      "#{page_title} - #{base_title}"
    end
  end

  # Turns booleans into on of two strings
  # Useful for showing or hiding elements conditionally
  # In it's default form you can think of it as saying 'display if ______'
  def d?(boolean_value, true_string = '', false_string = 'display: none;')
    (boolean_value) ? true_string : false_string
  end

end
