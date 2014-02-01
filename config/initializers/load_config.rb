APP_CONFIG = YAML.load_file("#{Rails.root}/config/config.yml")[Rails.env]
BADGE_MAKER_CONFIG = BadgeMaker.init