APP_CONFIG = YAML.load_file("#{Rails.root}/config/config.yml")[Rails.env]
COLORS = YAML.load_file("#{Rails.root}/config/colors.yml")
BADGE_MAKER_CONFIG = BadgeMaker.init