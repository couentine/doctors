Stripe.api_key = ENV['stripe_secret_key']

# First build out the subscription plan constants from the config yaml
all_subscription_plans = {} # plan_id => plan_fields
subscription_options = {} # price_group => array of array pairs usable in form <select> options
APP_CONFIG['subscription_plans'].each do |price_group, plans|
  all_subscription_plans = all_subscription_plans.merge plans
  subscription_options[price_group] = plans.map do |plan_id, plan_fields|
    [
      "#{plan_fields['name']} ($#{plan_fields['amount']/100} per #{plan_fields['interval']})",
      plan_id
    ]
  end
end

# Save these as constants
ALL_SUBSCRIPTION_PLANS = all_subscription_plans
SUBSCRIPTION_OPTIONS = subscription_options

# Save the plans to stripe if needed
StripeSubscriptionWorker.perform_async(ALL_SUBSCRIPTION_PLANS)
