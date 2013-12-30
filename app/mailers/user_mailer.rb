class UserMailer < ActionMailer::Base
  include EmailTools

  def group_member_add(to_user, from_user, group)
    @to_user, @from_user, @group = to_user, from_user, group

    mail(
      :subject  => "Welcome to #{group.name}!",
      :to       => to_user.email_name,
      :from     => build_from_string(from_user),
      :reply_to => from_user.email_name,
      :tag      => 'group_member_add,user_mailer'
    )
  end

  def group_admin_add(to_user, from_user, group)
    @to_user, @from_user, @group = to_user, from_user, group

    mail(
      :subject  => "You're now an admin of #{group.name}",
      :to       => to_user.email_name,
      :from     => build_from_string(from_user),
      :reply_to => from_user.email_name,
      :tag      => 'group_admin_add,user_mailer'
    )
  end

  def badge_learner_add(to_user, from_user, group, badge, log)
    @to_user, @from_user, @group, @badge, @log = to_user, from_user, group, badge, log

    mail(
      :subject  => "You've been added to a badge",
      :to       => to_user.email_name,
      :from     => build_from_string(from_user),
      :reply_to => from_user.email_name,
      :tag      => 'badge_learner_add,user_mailer'
    )
  end

  def badge_achieved(to_user, from_user, group, badge, log)
    @to_user, @from_user, @group, @badge, @log = to_user, from_user, group, badge, log

    mail(
      :subject  => "You've been issued a badge",
      :to       => to_user.email_name,
      :from     => build_from_string(from_user),
      :reply_to => from_user.email_name,
      :tag      => 'badge_achieved,user_mailer'
    )
  end

end
