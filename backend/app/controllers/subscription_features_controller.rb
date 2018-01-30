class SubscriptionFeaturesController < ApplicationController

  # GET /i/subscription_features
  # Returns JSON array of all possible subscription features
  def index
    render json: ACTIVE_SUBSCRIPTION_FEATURES
  end

end
