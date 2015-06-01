class WebhooksController < ApplicationController

  # Turn off protection for the webhook action
  protect_from_forgery :except => :stripe_event

  # POST /h/stripe_event
  # This endpoint receives event updates from Stripe (refer to https://stripe.com/docs/webhooks)
  def stripe_event
    begin
      event = JSON.parse(request.body.read)

      case event['type']
      when 'invoice.payment_succeeded'
        Group.delay(queue: 'high').refresh_stripe_subscription(
          event['data']['object']['subscription'], nil, 'stripe')
      when 'invoice.payment_failed'
        Group.delay(queue: 'high').refresh_stripe_subscription(
          event['data']['object']['subscription'], nil, 'stripe', 
          Time.at(event['data']['object']['date']), 
          Time.at(event['data']['object']['next_payment_attempt']))
      end

      render nothing: true, status: :ok
    rescue Exception => e
      render nothing: true, status: :internal_server_error
    end

  end

end
