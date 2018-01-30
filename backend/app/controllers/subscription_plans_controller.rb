class SubscriptionPlansController < ApplicationController

  # GET /i/subscription_plans
  # Returns JSON array of all active subscription plans
  def index
    render json: ACTIVE_SUBSCRIPTION_PLANS
  end

end
