class LtiController < ApplicationController

  # POST /h/lti/launch
  # This endpoint receives event updates from Stripe (refer to https://stripe.com/docs/webhooks)
  def launch
    begin
      # render nothing: true, status: :ok

      render json: { lti_status: Group.get_lti_status(params), params: params }
    rescue Exception => e
      render nothing: true, status: :internal_server_error
    end

  end

end
