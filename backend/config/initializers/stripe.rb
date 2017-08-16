Stripe.api_key = ENV['stripe_secret_key']
Stripe.api_version = ENV['stripe_api_version']

# First build out the subscription plan constants from the config yaml
all_subscription_plans = {} # plan_id => plan_fields
subscription_options = { 'admin' => [] } # pricing_group => array[pairs] for form <select> options
subscription_pricing_group = {} # plan_id => pricing_group
APP_CONFIG['subscription_plans'].each do |pricing_group, plans|
  all_subscription_plans = all_subscription_plans.merge plans
  subscription_options[pricing_group] = []
  plans.each do |plan_id, plan_fields|
    subscription_pricing_group[plan_id] = pricing_group
    subscription_options[pricing_group] << [
      "<b title='#{plan_fields['description']}' data-toggle='tooltip'>".html_safe \
        + "<i class='fa #{plan_fields['icon']}'></i> #{plan_fields['name']}</b>".html_safe \
        + "<span><em>$#{plan_fields['amount']/100} per #{plan_fields['interval']}".html_safe \
        + "</em></span>".html_safe,
      plan_id
    ]
    unless pricing_group == 'retired'
      subscription_options['admin'] << [
        "#{plan_fields['name']} ($#{plan_fields['amount']/100} per #{plan_fields['interval']})",
        plan_id
      ]
    end
  end
end

# Save these as constants
ALL_SUBSCRIPTION_PLANS = all_subscription_plans
SUBSCRIPTION_OPTIONS = subscription_options
SUBSCRIPTION_PRICING_GROUP = subscription_pricing_group

# Save the plans to stripe if needed
StripeSubscriptionWorker.perform_async(ALL_SUBSCRIPTION_PLANS)
