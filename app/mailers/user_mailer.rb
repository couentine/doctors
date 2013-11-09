class UserMailer < ActionMailer::Base
  include EmailTools

  def group_member_add(to_user, from_user, group)
    @to_user, @from_user, @group = to_user, from_user, group

    mail(
      :subject  => "New Learning Group Membership: #{group.name}",
      :to       => to_user.email_name,
      :from     => build_from_string(from_user),
      :reply_to => from_user.email_name,
      :tag      => 'group_member_add,user_mailer'
    )
  end

  def group_admin_add(to_user, from_user, group)
    @to_user, @from_user, @group = to_user, from_user, group

    mail(
      :subject  => "New Learning Group Admin Invitation: #{group.name}",
      :to       => to_user.email_name,
      :from     => build_from_string(from_user),
      :reply_to => from_user.email_name,
      :tag      => 'group_admin_add,user_mailer'
    )
  end

end
