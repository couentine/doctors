class UserMailer < ActionMailer::Base
  include EmailTools

  def group_admin_add(to_user, from_user, group, badges)
    @to_user, @from_user, @group, @badges = to_user, from_user, group, badges

    mail(
      :subject  => "You're now an admin of #{group.name}",
      :to       => to_user.email_name,
      :from     => build_from_string(from_user),
      :reply_to => from_user.email_name,
      :tag      => 'group_admin_add,user_mailer'
    )
  end

  def group_member_add(to_user, from_user, group, badges)
    @to_user, @from_user, @group, @badges = to_user, from_user, group, badges

    mail(
      :subject  => "Welcome to #{group.name}!",
      :to       => to_user.email_name,
      :from     => build_from_string(from_user),
      :reply_to => from_user.email_name,
      :tag      => 'group_member_add,user_mailer'
    )
  end

  def log_badge_issued(to_user, group, badge, log)
    @to_user, @group, @badge, @log = to_user, group, badge, log
    @to_creator = (to_user == @badge.creator)

    subject = (@to_creator) ? "You've created and earned a new badge" : "You've been awarded a badge"
    mail(
      :subject  => subject,
      :to       => to_user.email_name,
      :from     => build_from_string,
      :reply_to => no_reply_to_string,
      :tag      => 'log_badge_issued,user_mailer'
    )
  end

  def log_badge_retracted(to_user, group, badge, log)
    @to_user, @group, @badge, @log = to_user, group, badge, log

    mail(
      :subject  => "Your badge has been retracted",
      :to       => to_user.email_name,
      :from     => build_from_string,
      :reply_to => no_reply_to_string,
      :tag      => 'log_validation_retracted,user_mailer'
    )
  end

  def log_new(to_user, from_user, group, badge, log)
    @to_user, @from_user, @group, @badge, @log = to_user, from_user, group, badge, log
    @from_self = @from_user == @to_user

    if @from_self
      subject = "You've joined a badge"
      from_string = build_from_string
      reply_to_string = no_reply_to_string
    else
      subject = "You've beed added to a badge"
      from_string = build_from_string(from_user)
      reply_to_string = from_user.email_name
    end

    mail(
      :subject  => subject,
      :to       => to_user.email_name,
      :from     => from_string,
      :reply_to => reply_to_string,
      :tag      => 'log_new,user_mailer'
    )
  end
  
  def log_validation_request(to_user, from_user, group, badge, log)
    @to_user, @from_user, @group, @badge, @log = to_user, from_user, group, badge, log

    mail(
      :subject  => "Validation Request for #{badge.name}",
      :to       => to_user.email_name,
      :from     => build_from_string(from_user),
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
      :from     => build_from_string(from_user),
      :reply_to => from_user.email_name,
      :tag      => 'log_validation_received,user_mailer'
    )
  end

end
