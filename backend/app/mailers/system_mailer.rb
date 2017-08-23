class SystemMailer < ActionMailer::Base
  include EmailTools

  layout 'email_standard'

  def form_user_discussion(to_email, from_user, goals, availability)
    @to_email, @from_user, @goals, @availability \
      = to_email, User.find(from_user), goals, availability

    mail(
      :subject  => "Badge List Discussion Request - #{from_user.name}",
      :to       => to_email,
      :from     => build_from_string(from_user),
      :reply_to => from_user.email_name,
      :tag      => 'form_user_discussion,system_mailer'
    )
  end

  def bl_admin_email(subject, title, html_body, link_text, link_url, color = 'blue_grey')
    @title = title
    @html_body = html_body
    @link_text = link_text
    @link_url = link_url
    @color = color

    mail(
      :subject  => subject,
      :to       => ENV['bl_admin_email'],
      :from     => build_from_string,
      :tag      => 'bl_admin_email,system_mailer'
    )
  end
  
end
