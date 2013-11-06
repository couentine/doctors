module UsersHelper

  # === CONSTANTS === #
  VALID_EMAIL_REGEX = /[a-z0-9\.\_\%\+\-]+@[a-z0-9\.\-]+\.[a-z]{2,4}/i
  COMBINED_EMAIL_REGEX = /("[^"]+")?(\s*<)?([a-z0-9\.\_\%\+\-]+@[a-z0-9\.\-]+\.[a-z]{2,4})(>)?/i

  # Returns the Gravatar (http://gravatar.com/) for the given user.
  # Accepts options: size, class
  def gravatar_for(user, options = { :size => 50 })
    gravatar_id = Digest::MD5::hexdigest(user.email.downcase)
    size = options[:size]
    img_class = "gravatar"
    
    if options.has_key?(:class) 
      img_class += " #{options[:class]}" 
    end

    gravatar_url = "https://secure.gravatar.com/avatar/#{gravatar_id}?s=#{size}"
    image_tag(gravatar_url, alt: user.name, class: img_class )
  end

  # Accepts string containing comma, semicolon, new-line or bar delimited emails
  # optionally including names using the "Full Name" <email@example.com> syntax.
  # Return hash = {
  #   :valid => {array of hashes with :email and :name keys}
  #   :invalid => {array of invalid email strings}
  def parse_emails(emails)
    valid_emails, invalid_emails = [], []
    
    if emails
      emails.downcase.gsub(/[;|\n]/, ",").split(/,/).each do |potential_full_email|
        if potential_full_email && !potential_full_email.strip.blank?
          email_parts = potential_full_email.scan(COMBINED_EMAIL_REGEX)

          if (email_parts.count > 0) && (email_parts[0][2])
            email = email_parts[0][2]
            if email_parts[0][0]
              name = email_parts[0][0].strip
            else
              name = nil
            end
            valid_emails << { :email => email, :name => name }
          else
            invalid_emails << potential_full_email
          end
        end
      end              
    end
    
    { :valid => valid_emails, :invalid => invalid_emails }
  end

  # Accepts a string array of emails to match
  # Return hash = {
  #   :matched_users => {array of matched users}, 
  #   :matched_emails => {array of matched emails}, 
  #   :unmatched_emails = {array of unmatched emails} }
  def match_emails_to_users(emails)
    matched_users = []
    matched_emails = []
    unmatched_emails = []

    User.where(:email.in => emails).each do |user|
      matched_users << user
      matched_emails << user.email
    end
    emails.each do |email| 
      unmatched_emails << email unless matched_emails.include? email
    end
    
    { :matched_users => matched_users, :matched_emails => matched_emails, 
      :unmatched_emails => unmatched_emails }
  end

end