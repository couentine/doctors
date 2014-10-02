class SystemMailer < ActionMailer::Base
  include EmailTools

  def form_user_discussion(to_email, from_user, goals, availability)
    @to_email, @from_user, @goals, @availability = to_email, from_user, goals, availability

    mail(
      :subject  => "Badge List Discussion Request - #{from_user.name}",
      :to       => to_email,
      :from     => build_from_string(from_user),
      :reply_to => from_user.email_name,
      :tag      => 'form_user_discussion,system_mailer'
    )
  end
  
end
