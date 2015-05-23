class UserMailer < ActionMailer::Base
  include EmailTools

  def group_admin_add(to_user_id, from_user_id, group_id, badge_ids)
    @to_user, @from_user, @group, @badges = User.find(to_user_id), User.find(from_user_id), \
      Group.find(group_id), Badge.where(:id.in => badge_ids)

    mail(
      :subject  => "You're now an admin of #{@group.name}",
      :to       => @to_user.email_name,
      :from     => build_from_string(@from_user),
      :reply_to => @from_user.email_name,
      :tag      => 'group_admin_add,user_mailer'
    )
  end

  def group_member_add(to_user_id, from_user_id, group_id, badge_ids)
    @to_user, @from_user, @group, @badges = User.find(to_user_id), User.find(from_user_id), \
      Group.find(group_id), Badge.where(:id.in => badge_ids)

    mail(
      :subject  => "Welcome to #{@group.name}!",
      :to       => @to_user.email_name,
      :from     => build_from_string(@from_user),
      :reply_to => @from_user.email_name,
      :tag      => 'group_member_add,user_mailer'
    )
  end

  def log_badge_issued(to_user_id, group_id, badge_id, log_id)
    @to_user, @group, @badge, @log = User.find(to_user_id), Group.find(group_id), \
      Badge.find(badge_id), Log.find(log_id)
    @to_creator = (@to_user == @badge.creator)

    subject = @to_creator ? "You've created and earned a new badge" : "You've been awarded a badge"
    mail(
      :subject  => subject,
      :to       => @to_user.email_name,
      :from     => build_from_string,
      :reply_to => no_reply_to_string,
      :tag      => 'log_badge_issued,user_mailer'
    )
  end

  def log_badge_retracted(to_user_id, group_id, badge_id, log_id)
    @to_user, @group, @badge, @log = User.find(to_user_id), Group.find(group_id), \
      Badge.find(badge_id), Log.find(log_id)

    mail(
      :subject  => "Your badge has been retracted",
      :to       => @to_user.email_name,
      :from     => build_from_string,
      :reply_to => no_reply_to_string,
      :tag      => 'log_validation_retracted,user_mailer'
    )
  end

  def log_new(to_user_id, from_user_id, group_id, badge_id, log_id)
    @to_user, @from_user, @group, @badge, @log = User.find(to_user_id), User.find(from_user_id), \
      Group.find(group_id), Badge.find(badge_id), Log.find(log_id)
    @from_self = @from_user == @to_user

    if @from_self
      subject = "You've joined a badge"
      from_string = build_from_string
      reply_to_string = no_reply_to_string
    else
      subject = "You've beed added to a badge"
      from_string = build_from_string(@from_user)
      reply_to_string = @from_user.email_name
    end

    mail(
      :subject  => subject,
      :to       => @to_user.email_name,
      :from     => from_string,
      :reply_to => reply_to_string,
      :tag      => 'log_new,user_mailer'
    )
  end
  
  def log_validation_request(to_user_id, from_user_id, group_id, badge_id, log_id)
    @to_user, @from_user, @group, @badge, @log = User.find(to_user_id), User.find(from_user_id), \
      Group.find(group_id), Badge.find(badge_id), Log.find(log_id)

    mail(
      :subject  => "Validation Request for #{@badge.name}",
      :to       => @to_user.email_name,
      :from     => build_from_string(@from_user),
      :reply_to => @from_user.email_name,
      :tag      => 'log_validation_request,user_mailer'
    )
  end

  def log_validation_received(to_user_id, from_user_id, group_id, badge_id, log_id, entry_id)
    @to_user, @from_user, @group, @badge, @log, @entry = User.find(to_user_id), \
      User.find(from_user_id), Group.find(group_id), Badge.find(badge_id), Log.find(log_id), \
      Entry.find(entry_id)

    mail(
      :subject  => "Expert Validation - #{@entry.summary}",
      :to       => @to_user.email_name,
      :from     => build_from_string(@from_user),
      :reply_to => @from_user.email_name,
      :tag      => 'log_validation_received,user_mailer'
    )
  end

end
