class WebhooksController < ApplicationController

  # Turn off protection for the webhook action
  protect_from_forgery :except => :stripe_event

  # POST /h/stripe_event
  # This endpoint receives event updates from Stripe (refer to https://stripe.com/docs/webhooks)
  def stripe_event
    begin
      event = JSON.parse(request.body.read)

      case event['type']
      when 'customer.subscription.created', 'customer.subscription.deleted'
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
      end

      # Save a copy of the request body if we're in development
      if Rails.env.development?
        item = InfoItem.new
        item.type = 'dev-log'
        item.name = 'Stripe Webhook Request Body'
        item.data = event.to_hash
        item.save
      end

      render nothing: true, status: :ok
    rescue Exception => e
      render nothing: true, status: :internal_server_error
    end

  end

end
