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
        GroupMailer.delay(retry: 10, queue: 'low').payment_failure(id)
      end

      # Save a copy of the request body as an info item
      item = InfoItem.new
      item.type = 'dev-log'
      item.name = 'Stripe Webhook Request Body'
      item.data = event.to_hash
      item.delete_at = 1.day.from_now if Rails.env.production?
      item.save

      render nothing: true, status: :ok
    rescue Exception => e
      render nothing: true, status: :internal_server_error
    end

  end

end
