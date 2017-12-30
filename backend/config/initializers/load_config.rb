APP_CONFIG = YAML.load_file("#{Rails.root}/config/config.yml")[Rails.env]
COLORS = YAML.load_file("#{Rails.root}/config/colors.yml")
BADGE_MAKER_CONFIG = BadgeMaker.init

# Build active subscription plans array from app config (so we don't have to build it everytime someone calls the API)
ACTIVE_SUBSCRIPTION_PLANS = APP_CONFIG['subscription_plans']['standard'].map do |id, value|
  { 'pricing_group' => 'standard', 'id' => id }.merge(value)
end + APP_CONFIG['subscription_plans']['k12'].map do |id, value|
  { 'pricing_group' => 'k12', 'id' => id }.merge(value)
end

# Build active subscription features array from app config (so we don't have to build it everytime someone calls the API)
ACTIVE_SUBSCRIPTION_FEATURES = APP_CONFIG['feature_details'].map do |id, value|
  { 'id' => id }.merge(value)
end