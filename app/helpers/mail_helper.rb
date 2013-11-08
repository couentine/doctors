module MailHelper

  # Returns a string in the form of "John Doe <email@example.com>"
  # from_user_or_email can be a User a name string or nil
  def build_from_string(from_user_or_name)
    if from_user_or_email.instance_of?(User) && !from_user_or_email.name.blank?
      "#{from_user_or_email.name} <#{APP_CONFIG['from_email']}>"
    elsif from_user_or_email.instance_of?(String) && !from_user_or_email.blank?
      "#{from_user_or_email}  <#{APP_CONFIG['from_email']}>"
    else
      "Badge List <#{APP_CONFIG['from_email']}>"
    end
  end

end
