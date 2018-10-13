class NewUserMailer < ActionMailer::Base
  include EmailTools

  layout 'email_standard'

  def group_member_add(to_email, to_name, from_user_id, group_id, badge_ids, invitation_message=nil)
    @to_email, @to_name = to_email, to_name
    @from_user, @group, @badges = User.find(from_user_id), Group.find(group_id), \
        Badge.where(:id.in => badge_ids)
    @invitation_message = invitation_message
    @user_key = Digest::MD5::hexdigest(@to_email.downcase)

    if @to_name.blank?
      to_email_name = @to_email
    else
      to_email_name = "#{@to_name} <#{@to_email}>"
    end

    mail(
      :subject  => "You've been invited to #{@group.name}",
      :to       => to_email_name,
      :from     => build_from_string(@from_user),
      :reply_to => @from_user.email_name,
      :tag      => 'group_member_add,new_user_mailer'
    )
  end

  def group_admin_add(to_email, to_name, from_user_id, group_id, badge_ids, invitation_message=nil)
    @to_email, @to_name = to_email, to_name
    @from_user, @group, @badges = User.find(from_user_id), Group.find(group_id), \
        Badge.where(:id.in => badge_ids)
    @invitation_message = invitation_message
    @user_key = Digest::MD5::hexdigest(@to_email.downcase)

    if @to_name.blank?
      to_email_name = @to_email
    else
      to_email_name = "#{@to_name} <#{@to_email}>"
    end

    mail(
      :subject  => "You've been invited to be an admin of #{@group.name}",
      :to       => to_email_name,
      :from     => build_from_string(@from_user),
      :reply_to => @from_user.email_name,
      :tag      => 'group_admin_add,new_user_mailer'
    )
  end

  def badge_issued(to_email, to_name, from_user_id, group_id, badge_id)
    @to_email, @to_name = to_email, to_name
    @from_user, @group, @badge = User.find(from_user_id), Group.find(group_id), \
      Badge.find(badge_id)
    @user_key = Digest::MD5::hexdigest(@to_email.downcase)

    if @to_name.blank?
      to_email_name = @to_email
    else
      to_email_name = "#{@to_name} <#{@to_email}>"
    end

    mail(
      :subject  => "You've been awarded the #{@badge.name} badge",
      :to       => to_email_name,
      :from     => build_from_string(@from_user),
      :reply_to => @from_user.email_name,
      :tag      => 'badge_issued,new_user_mailer'
    )
  end

end
