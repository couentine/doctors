class NewUserMailer < ActionMailer::Base
  helper :mail

  def group_member_add(to_email, to_name, from_user, group)
    @to_email, @to_name, @from_user, @group = to_email, to_name, from_user, group

    if @to_name.blank?
      to_email_name = @to_email
    else
      to_email_name = "@to_name <@to_email>"
    end

    mail(
      :subject  => "Badge List Learning Group Invitation: #{group.name}",
      :to       => to_email_name,
      :from     => build_from_string(from_user),
      :reply_to => from_user.email_name,
      :tag      => 'group_member_add,new_user_mailer'
    )
  end

  def group_admin_add(to_email, to_name, from_user, group)
    @to_email, @to_name, @from_user, @group = to_email, to_name, from_user, group

    if @to_name.blank?
      to_email_name = @to_email
    else
      to_email_name = "@to_name <@to_email>"
    end

    mail(
      :subject  => "Badge List Learning Group Invitation: #{group.name}",
      :to       => to_email_name,
      :from     => build_from_string(from_user),
      :reply_to => from_user.email_name,
      :tag      => 'group_admin_add,new_user_mailer'
    )
  end

end
