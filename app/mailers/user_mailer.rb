class UserMailer < ActionMailer::Base
  include EmailTools

  def group_admin_add(to_user, from_user, group)
    @to_user, @from_user, @group = to_user, from_user, group

    mail(
      :subject  => "You're now an admin of #{group.name}",
      :to       => to_user.email_name,
      :from     => from_user.email_name,
      :reply_to => from_user.email_name,
      :tag      => 'group_admin_add,user_mailer'
    )
  end

  def group_member_add(to_user, from_user, group)
    @to_user, @from_user, @group = to_user, from_user, group

    mail(
      :subject  => "Welcome to #{group.name}!",
      :to       => to_user.email_name,
      :from     => from_user.email_name,
      :reply_to => from_user.email_name,
      :tag      => 'group_member_add,user_mailer'
    )
  end

  def log_badge_issued(to_user, group, badge, log)
    @to_user, @group, @badge, @log = to_user, group, badge, log

    mail(
      :subject  => "You've been issued a badge",
      :to       => to_user.email_name,
      :from     => build_from_string,
      :reply_to => build_from_string,
      :tag      => 'log_badge_issued,user_mailer'
    )
  end

  def log_badge_retracted(to_user, group, badge, log)
    @to_user, @group, @badge, @log = to_user, group, badge, log

    mail(
      :subject  => "Your badge has been retracted",
      :to       => to_user.email_name,
      :from     => build_from_string,
      :reply_to => build_from_string,
      :tag      => 'log_validation_retracted,user_mailer'
    )
  end

  def log_new(to_user, from_user, group, badge, log)
    @to_user, @from_user, @group, @badge, @log = to_user, from_user, group, badge, log
    @from_self = @from_user == @to_user

    if @from_self
      subject = "You've joined a badge"
    else
      subject = "You've beed added to a badge"
    end

    mail(
      :subject  => subject,
      :to       => to_user.email_name,
      :from     => (@from_self) ? build_from_string : from_user.email_name,
      :reply_to => (@from_self) ? build_from_string : from_user.email_name,
      :tag      => 'log_new,user_mailer'
    )
  end
  
  def log_validation_request(to_user, from_user, group, badge, log)
    @to_user, @from_user, @group, @badge, @log = to_user, from_user, group, badge, log

    mail(
      :subject  => "Learning Validation Request",
      :to       => to_user.email_name,
      :from     => from_user.email_name,
      :reply_to => from_user.email_name,
      :tag      => 'log_validation_request,user_mailer'
    )
  end

  def log_validation_received(to_user, from_user, group, badge, log, entry)
    @to_user, @from_user, @group, @badge, @log = to_user, from_user, group, badge, log
    @entry = entry

    mail(
      :subject  => "Expert Validation - #{entry.summary}",
      :to       => to_user.email_name,
      :from     => from_user.email_name,
      :reply_to => from_user.email_name,
      :tag      => 'log_validation_received,user_mailer'
    )
  end

end
