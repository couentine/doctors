class GroupMailer < ActionMailer::Base
  include EmailTools
  include ActionView::Helpers::TextHelper

  layout 'email_standard'

  def trial_ending(group_id)
    @group = Group.find(group_id)
    @trial_end_date = @group.subscription_end_date || Time.now
    @days_until_end = ((@trial_end_date - Time.now) / 86400).round
    @payment_info_needed = !@group.owner.has_stripe_card?

    if @payment_info_needed
      @subject = "We need your billing info"
    else
      @subject = "#{@group.name} trial ends in #{pluralize @days_until_end, 'day'}"
    end

    mail(
      :subject  => @subject,
      :to       => @group.owner.email_name,
      :from     => build_from_string,
      :reply_to => build_from_string,
      :tag      => 'group_mailer,trial_ending'
    )
  end

  def payment_failure(group_id)
    @group = Group.find(group_id)
    @payment_fail_date = @group.stripe_payment_fail_date
    @retry_date = @group.stripe_payment_retry_date || Time.now
    @days_until_retry = ((@retry_date - Time.now) / 86400).round
    
    subject = "Billing charge declined"

    mail(
      :subject  => subject,
      :to       => @group.owner.email_name,
      :from     => build_from_string,
      :reply_to => build_from_string,
      :tag      => 'group_mailer,payment_failure'
    )
  end

  def subscription_canceled(group_id)
    @group = Group.find(group_id)

    mail(
      :subject  => "Your subscription has been canceled",
      :to       => @group.owner.email_name,
      :from     => build_from_string,
      :reply_to => build_from_string,
      :tag      => 'group_mailer,subscription_canceled'
    )
  end

  def group_transfer(group_id)
    @group = Group.find(group_id)
    @previous_owner = User.find(@group.previous_owner_id) rescue nil

    if @previous_owner
      from_string = build_from_string @previous_owner
      reply_to_string = @previous_owner.email_name
    else
      from_string = build_from_string
      reply_to_string = build_from_string
    end

    mail(
      :subject  => "You're the new owner of #{@group.name}",
      :to       => @group.owner.email_name,
      :from     => from_string,
      :reply_to => reply_to_string,
      :tag      => 'group_mailer,group_transfer'
    )
  end

end
