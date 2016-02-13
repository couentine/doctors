class WebhooksController < ApplicationController

  # Turn off protection for the webhook action
  protect_from_forgery :except => :stripe_event

  # POST /h/stripe_event
  # This endpoint receives event updates from Stripe (refer to https://stripe.com/docs/webhooks)
  def stripe_event
    begin
      event = JSON.parse(request.body.read)

      case event['type']
      when 'customer.subscription.created'
        Group.delay(queue: 'high').refresh_stripe_subscription(\
          event['data']['object']['id'], context: 'stripe', queue_send_trial_ending_email: true)
      when 'customer.subscription.deleted'
        Group.delay(queue: 'high').refresh_stripe_subscription(\
          event['data']['object']['id'], context: 'stripe')
      when 'invoice.payment_succeeded'
        Group.delay(queue: 'high').refresh_stripe_subscription(\
          event['data']['object']['subscription'], context: 'stripe', info_item_data: event)
      when 'invoice.payment_failed'
        Group.delay(queue: 'high').refresh_stripe_subscription(\
          event['data']['object']['subscription'], context: 'stripe', info_item_data: event,\
          payment_fail_date: Time.at(event['data']['object']['date']), \
          payment_retry_date: Time.at(event['data']['object']['next_payment_attempt']))
        group = Group.find_by(stripe_subscription_id: event['data']['object']['subscription']) \
          rescue nil
        if group
          GroupMailer.delay(retry: 5, queue: 'low').payment_failure(group.id)
        end
      end

      # Save a copy of the request body as an info item
      item = InfoItem.new
      item.type = 'webhook-log-stripe-event'
      item.name = 'Stripe Webhook Request Body'
      item.data = event.to_hash
      # For now let's keep all of these...
      # item.delete_at = 1.day.from_now if Rails.env.production?
      item.save

      render nothing: true, status: :ok
    rescue Exception => e
      render nothing: true, status: :internal_server_error
    end

  end

  # POST /h/postmark_bounce?key=abc123
  # This endpoint receives bounces from Postmark 
  # Documentation at http://developer.postmarkapp.com/developer-bounce-webhook.html
  def postmark_bounce
    begin
      if params[:key] == ENV['POSTMARK_WEBHOOK_KEY']
        bounce = JSON.parse(request.body.read)

        # Parse the datetime field
        bounced_at = DateTime.parse(bounce['BouncedAt']) rescue Time.now

        # Then track the bounce
        User.delay(queue: 'low', retry: false)\
          .track_bounce(bounce['Email'], bounce['Inactive'], bounced_at, bounce['ID'])

        # Save a copy of the request body as an info item
        item = InfoItem.new
        item.type = 'webhook-log-postmark-bounce'
        item.name = 'Postmark Bounce Webhook Request Body'
        item.data = bounce.to_hash
        # For now let's keep all of these...
        # item.delete_at = 1.day.from_now if Rails.env.production?
        item.save

        render nothing: true, status: :ok
      else
        render nothing: true, status: :forbidden
      end
      
    rescue Exception => e
      render nothing: true, status: :internal_server_error
    end

  end

end
