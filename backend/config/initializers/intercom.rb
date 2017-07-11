IntercomRails.config do |config|
  # Init the RAILS gem
  config.app_id = ENV['INTERCOM_APP_ID']
  
  # Init the normal RUBY gem
# intercom = Intercom::Client.new(app_id: ENV['INTERCOM_APP_ID'], api_key: ENV['INTERCOM_API_KEY'])

  # == Intercom secret key
  # This is required to enable secure mode, you can find it on your Setup
  # guide in the "Secure Mode" step.
  #
  # config.api_secret = "..."

  # == Intercom API Key
  # This is required for some Intercom rake tasks like importing your users;
  # you can generate one at https://app.intercom.io/apps/api_keys.
  #
  # config.api_key = "..."

  # == Enabled Environments
  # Which environments is auto inclusion of the Javascript enabled for
  #
  config.enabled_environments = ["development", "production"]

  # == Current user method/variable
  # The method/variable that contains the logged in user in your controllers.
  # If it is `current_user` or `@user`, then you can ignore this
  #
  config.user.current = Proc.new { current_user }
  # Note on the above: I'm setting this because @user is used for other things so I want
  # to be sure to hard code it to only current_user.

  # == Include for logged out Users
  # If set to true, include the Intercom messenger on all pages, regardless of whether
  # The user model class (set below) is present. Only available for Apps on the Acquire plan.
  # config.include_for_logged_out_users = true

  # == User model class
  # The class which defines your user model
  #
  # config.user.model = Proc.new { User }

  # == Exclude users
  # A Proc that given a user returns true if the user should be excluded
  # from imports and Javascript inclusion, false otherwise.
  #
  config.user.exclude_if = Proc.new { |user| !user.show_in_intercom? }

  # == User Custom Data
  # A hash of additional data you wish to send about your users.
  # You can provide either a method name which will be sent to the current
  # user object, or a Proc which will be passed the current user.
  config.user.custom_data = {
    :username => :username_with_caps,
    :profile_url => :profile_url,
    :flags => :flags,
    :admin => :admin
  }
  # Removed these because they were causing queries
    # :created_group_count => Proc.new{ |user| (user.created_group_ids || []).count },
    # :owned_group_count => Proc.new{ |user| (user.owned_group_ids || []).count },
    # :created_badge_count => Proc.new{ |user| (user.created_badge_ids || []).count },
    # :entry_count => Proc.new{ |user| (user.created_entry_ids || []).count }

  # == User -> Company association
  # A Proc that given a user returns an array of companies
  # that the user belongs to.
  #
  # config.user.company_association = Proc.new { |user| user.companies.to_a }
  # config.user.company_association = Proc.new { |user| [user.company] }

  # == Current company method/variable
  # The method/variable that contains the current company for the current user,
  # in your controllers. 'Companies' are generic groupings of users, so this
  # could be a company, app or group.
  #
  config.company.current = Proc.new { @current_user_group }

  # == Company Custom Data
  # A hash of additional data you wish to send about a company.
  # This works the same as User custom data above.
  config.company.custom_data = {
    :last_activity_at => Proc.new { Time.now },
    :group_url => :group_url,
    :location => :location,
    :website => :website,
    :type => :type,
    :flags => :flags,
    :user_limit => :user_limit,
    :admin_limit => :admin_limit,
    :sub_group_limit => :sub_group_limit,
    :total_user_count => :total_user_count,
    :admin_count => :admin_count,
    :member_count => :member_count,
    :sub_group_count => :sub_group_count,
    :pricing_group => :pricing_group,
    :subscription_plan => :subscription_plan,
    :subscription_end_date => :subscription_end_date,
    :stripe_payment_fail_date => :stripe_payment_fail_date,
    :stripe_payment_retry_date => :stripe_payment_retry_date,
    :stripe_subscription_card => :stripe_subscription_card,
    :stripe_subscription_id => :stripe_subscription_id,
    :stripe_subscription_status => :stripe_subscription_status,
    :creator => :creator_id,
    :owner => :owner_id,
    :badge_count => Proc.new { |group| (group.badge_ids || []).count }
  }

  # == Company Plan name
  # This is the name of the plan a company is currently paying (or not paying) for.
  # e.g. Messaging, Free, Pro, etc.
  config.company.plan = Proc.new do |group| 
    if group.subscription_plan
      group.subscription_plan_name
    else
      nil
    end
  end

  # == Company Monthly Spend
  # This is the amount the company spends each month on your app. If your company
  # has a plan, it will set the 'total value' of that plan appropriately.
  config.company.monthly_spend = Proc.new do |group| 
    if group.subscription_plan && ALL_SUBSCRIPTION_PLANS[group.subscription_plan]
      if ALL_SUBSCRIPTION_PLANS[group.subscription_plan]['interval'] == 'month'
        ALL_SUBSCRIPTION_PLANS[group.subscription_plan]['amount'] / 100
      elsif ALL_SUBSCRIPTION_PLANS[group.subscription_plan]['interval'] == 'year'
        ALL_SUBSCRIPTION_PLANS[group.subscription_plan]['amount'] / 12 / 100
      else
        0
      end
    else
      nil
    end
  end

  # == Custom Style
  # By default, Intercom will add a button that opens the messenger to
  # the page. If you'd like to use your own link to open the messenger,
  # uncomment this line and clicks on any element with id 'Intercom' will
  # open the messenger.
  #
  # config.inbox.style = :custom
end
