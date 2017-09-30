class UserMailer < ActionMailer::Base
  include EmailTools

  layout 'email_standard'

  def group_admin_add(to_user_id, from_user_id, group_id, badge_ids, invitation_message=nil)
    @to_user = User.find(to_user_id)
    @from_user = User.find(from_user_id)
    @group = Group.find(group_id)
    @badges = Badge.where(:id.in => badge_ids)

    @invitation_message = invitation_message

    mail(
      :subject  => "You're now an admin of #{@group.name}",
      :to       => @to_user.email_name,
      :from     => build_from_string(@from_user),
      :reply_to => @from_user.email_name,
      :tag      => 'group_admin_add,user_mailer'
    )
  end

  def group_member_add(to_user_id, from_user_id, group_id, badge_ids, invitation_message=nil)
    @to_user = User.find(to_user_id)
    @from_user = User.find(from_user_id)
    @group = Group.find(group_id)
    @badges = Badge.where(:id.in => badge_ids)

    @invitation_message = invitation_message

    mail(
      :subject  => "You're now a member of #{@group.name}",
      :to       => @to_user.email_name,
      :from     => build_from_string(@from_user),
      :reply_to => @from_user.email_name,
      :tag      => 'group_member_add,user_mailer'
    )
  end

  def group_welcome_message(to_user_id, group_id, badge_ids)
    @to_user = User.find(to_user_id)
    @group = Group.find(group_id)
    @badges = Badge.where(:id.in => badge_ids)

    mail(
      :subject  => "Welcome to #{@group.name}!",
      :to       => @to_user.email_name,
      :from     => build_from_string,
      :reply_to => build_from_string,
      :tag      => 'group_welcome_message,user_mailer'
    )
  end

  def log_badge_issued(to_user_id, group_id, badge_id, log_id)
    @to_user = User.find(to_user_id)
    @group = Group.find(group_id)
    @badge = Badge.find(badge_id)
    @log = Log.find(log_id)

    subject = "You've been awarded a badge"
    mail(
      :subject  => subject,
      :to       => @to_user.email_name,
      :from     => build_from_string,
      :reply_to => no_reply_to_string,
      :tag      => 'log_badge_issued,user_mailer'
    )
  end

  def log_badge_retracted(to_user_id, group_id, badge_id, log_id)
    @to_user = User.find(to_user_id)
    @group = Group.find(group_id)
    @badge = Badge.find(badge_id)
    @log = Log.find(log_id)

    if @log.retracted_by
      # Retracted by is an id field not a user field so we need to query for it
      @retracted_by = User.find(@log.retracted_by) rescue nil 
    end

    mail(
      :subject  => "Your badge has been retracted",
      :to       => @to_user.email_name,
      :from     => build_from_string,
      :reply_to => no_reply_to_string,
      :tag      => 'log_validation_retracted,user_mailer'
    )
  end

  def log_new(to_user_id, from_user_id, group_id, badge_id, log_id, invitation_message=nil)
    @to_user = User.find(to_user_id)
    @from_user = User.find(from_user_id)
    @group = Group.find(group_id)
    @badge = Badge.find(badge_id)
    @log = Log.find(log_id)

    @from_self = @from_user == @to_user
    @invitation_message = invitation_message

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
    @to_user = User.find(to_user_id)
    @from_user = User.find(from_user_id)
    @group = Group.find(group_id)
    @badge = Badge.find(badge_id)
    @log = Log.find(log_id)

    @is_badge_member = @to_user.learner_of?(@badge) || @to_user.expert_of?(@badge)
    
    mail(
      :subject  => "Feedback Request for #{@badge.name}",
      :to       => @to_user.email_name,
      :from     => build_from_string(@from_user),
      :reply_to => @from_user.email_name,
      :tag      => 'log_validation_request,user_mailer'
    )
  end

  def log_validation_received(to_user_id, from_user_id, group_id, badge_id, log_id, entry_id)
    @to_user = User.find(to_user_id)
    @from_user = User.find(from_user_id)
    @group = Group.find(group_id)
    @badge = Badge.find(badge_id)
    @log = Log.find(log_id)
    @entry = Entry.find(entry_id)

    @noun = (@entry.log_validated) ? "endorsement" : "feedback"
    @Noun = @noun.capitalize

    mail(
      :subject  => "#{@Noun} for #{@badge.name}",
      :to       => @to_user.email_name,
      :from     => build_from_string(@from_user),
      :reply_to => @from_user.email_name,
      :tag      => 'log_validation_received,user_mailer'
    )
  end

  def entry_invalid_image(entry_id)
    @entry = Entry.find(entry_id)
    @to_user = @entry.creator
    @log = @entry.log
    @badge = @log.badge
    @group = @badge.group

    mail(
      :subject  => 'Oops! Your image evidence could not be posted.',
      :to       => @to_user.email_name,
      :from     => build_from_string,
      :reply_to => build_from_string,
      :tag      => 'entry_invalid_image,user_mailer'
    )
  end

  def group_new_lti_integration(to_user_id, group_id, lti_context_details)
    @to_user = User.find(to_user_id)
    @group = Group.find(group_id)
    @creator_user = User.find(lti_context_details['creator_user_id']) rescue nil

    @lti_context_details = lti_context_details

    mail(
      :subject  => 'New LTI integration activated',
      :to       => @to_user.email_name,
      :from     => build_from_string,
      :reply_to => build_from_string,
      :tag      => 'group_new_lti_integration,user_mailer'
    )
  end

end
