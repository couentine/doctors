module EmailTools

  # === CONSTANTS === #
  VALID_EMAIL_REGEX = /[a-z0-9\.\_\%\+\-]+@[a-z0-9\.\-]+\.[a-z]{2,4}/i
  COMBINED_EMAIL_REGEX = /("[^"]+")?(\s*<)?([a-z0-9\.\_\%\+\-]+@[a-z0-9\.\-]+\.[a-z]{2,4})(>)?/i

  # Returns a string in the form of "John Doe <app@badgelist.com>"
  # NOTE: This will return a mocked from string with the user's name and the system email
  #       in order to be compatible with postmark.
  def build_from_string(from_user = nil)
    if from_user.nil? || from_user.name.blank?
      "Badge List <#{ENV['from_email']}>"
    else
      "#{from_user.name} <#{ENV['from_email']}>"
    end
  end

  def no_reply_to_string
    "Badge List <no-reply@badgelist.com>"
  end

  # Accepts string containing comma, semicolon, new-line or bar delimited emails
  # optionally including names using the "Full Name" <email@example.com> syntax.
  # Return hash = {
  #   :valid => {array of hashes with :email and :name keys}
  #   :invalid => {array of invalid email strings}
  def parse_emails(emails)
    valid_emails, invalid_emails = [], []
    
    if emails
      emails.gsub(/[;|\n]/, ",").split(/,/).each do |potential_full_email|
        if potential_full_email && !potential_full_email.strip.blank?
          email_parts = potential_full_email.scan(COMBINED_EMAIL_REGEX)

          if (email_parts.count > 0) && (email_parts[0][2])
            email = email_parts[0][2].downcase
            if email_parts[0][0]
              name = email_parts[0][0].strip.gsub(/"/, '')
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