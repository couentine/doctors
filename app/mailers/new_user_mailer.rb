class NewUserMailer < ActionMailer::Base
  include EmailTools

  def group_member_add(to_email, to_name, from_user, group, badges)
    @to_email, @to_name, @from_user, @group, @badges = to_email, to_name, from_user, group, badges

    if @to_name.blank?
      to_email_name = @to_email
    else
      to_email_name = "#{@to_name} <#{@to_email}>"
    end

    mail(
      :subject  => "Welcome to #{group.name}!",
      :to       => to_email_name,
      :from     => build_from_string(from_user),
      :reply_to => from_user.email_name,
      :tag      => 'group_member_add,new_user_mailer'
    )
  end

  def group_admin_add(to_email, to_name, from_user, group, badges)
    @to_email, @to_name, @from_user, @group, @badges = to_email, to_name, from_user, group, badges

    if @to_name.blank?
      to_email_name = @to_email
    else
      to_email_name = "#{@to_name} <#{@to_email}>"
    end

    mail(
      :subject  => "You're now an admin of #{group.name}",
      :to       => to_email_name,
      :from     => build_from_string(from_user),
      :reply_to => from_user.email_name,
      :tag      => 'group_admin_add,new_user_mailer'
    )
  end

  def badge_issued(to_email, to_name, from_user, group, badge)
    @to_email, @to_name, @from_user, @group, @badge = to_email, to_name, from_user, group, badge

    if @to_name.blank?
      to_email_name = @to_email
    else
      to_email_name = "#{@to_name} <#{@to_email}>"
    end

    mail(
      :subject  => "You've been issued the #{badge.name} badge!",
      :to       => to_email_name,
      :from     => build_from_string(from_user),
      :reply_to => from_user.email_name,
      :tag      => 'badge_issued,new_user_mailer'
    )
  end

end
