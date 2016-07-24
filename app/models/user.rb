class User
  include Mongoid::Document
  include Mongoid::Timestamps
  include JSONFilter
  include JSONTemplater

  # === CONSTANTS === #
  
  MIN_PASSWORD_LENGTH = 6 # Note: This is just for use in tests & not actually tied to anything
  MAX_NAME_LENGTH = 200
  MAX_USERNAME_LENGTH = 15
  JSON_FIELDS = [:name, :username, :username_with_caps]
  JSON_MOCK_FIELDS = { :avatar_image_url => :avatar_image_url }

  JSON_TEMPLATES = {
    current_user: [:id, :name, :username, :username_with_caps, :admin, :avatar_image_url, 
      :avatar_image_medium_url, :avatar_image_small_url, :email_inactive]
  }

  INACTIVE_EMAIL_LIST_KEY = 'postmark-inactive-emails'
  MAX_EMAIL_BOUNCES = 3
  EMAIL_BOUNCE_MEMORY = 14 # days
  HALF_OFF_FLAG = '50_percent_off'

  # === RELATIONSHIP === #

  has_many :created_groups, inverse_of: :creator, class_name: "Group"
  has_many :owned_groups, inverse_of: :owner, class_name: "Group"
  has_many :created_badges, inverse_of: :creator, class_name: "Badge"
  has_many :logs, dependent: :destroy
  has_many :created_entries, inverse_of: :creator, class_name: "Entry"
  has_and_belongs_to_many :admin_of, inverse_of: :admins, class_name: "Group"
  has_and_belongs_to_many :member_of, inverse_of: :members, class_name: "Group"
  has_many :info_items, dependent: :destroy
  belongs_to :domain, inverse_of: :users, class_name: "Domain" # don't ever set this manually,
  has_many :owned_domains, inverse_of: :owner, class_name: "Domain"

  # === CUSTOM FIELDS & VALIDATIONS === #
  
  field :name,                          type: String
  field :username,                      type: String
  field :username_with_caps,            type: String
  field :has_private_domain,            type: Boolean, default: false
  field :is_non_private_domain_user,    type: Boolean, default: false
  field :visible_to_domain_urls,        type: Array
  field :flags,                         type: Array, default: [], pre_processed: true
  field :admin,                         type: Boolean, default: false
  field :form_submissions,              type: Array
  field :last_active,                   type: Date
  field :last_active_at,                type: Time # RETIRED
  field :active_months,                 type: Array # RETIRED
  field :page_views,                    type: Hash # RETIRED
  field :email_inactive,                type: Boolean, default: false
  field :email_bounces,                 type: Integer, default: 0
  field :last_email_bounce_at,          type: Time
  field :inactive_email_bounce_id,      type: Integer

  mount_uploader :direct_avatar,        S3DirectUploader
  mount_uploader :avatar,               S3AvatarUploader
  field :avatar_key,                    type: String
  field :processing_avatar,             type: Boolean

  field :identity_hash,                 type: String
  field :identity_salt,                 type: String

  field :stripe_customer_id,            type: String
  field :stripe_default_source,         type: String
  field :stripe_cards,                  type: Array, default: []

  field :expert_badge_ids,              type: Array, default: []
  field :learner_badge_ids,             type: Array, default: []
  field :all_badge_ids,                 type: Array, default: []

  # OmniAuth Fields
  field :user_defined_password,         type: Boolean, default: true
  field :auto_username_needs_review,    type: Boolean, default: false
  field :omniauth_last_provider,        type: String
  field :omniauth_google_oauth2_uid,    type: String
  field :omniauth_google_oauth2_hash,   type: Hash # stores the full auth hash

  validates :name, presence: true, length: { maximum: MAX_NAME_LENGTH }
  validates :username_with_caps, presence: true, length: { within: 2..MAX_USERNAME_LENGTH }, 
    uniqueness:true, format: { with: /\A[\w-]+\Z/, 
      message: "can only contain letters, numbers, dashes and underscores." }
  validates :username, presence: true, length: { within: 2..MAX_USERNAME_LENGTH }, uniqueness:true,
    format: { with: /\A[\w-]+\Z/, 
      message: "can only contain letters, numbers, dashes and underscores." }

  
  # === DEVISE SETTINGS === #

  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable, :registerable, :recoverable, :rememberable, :trackable, 
    :validatable, :confirmable, :lockable, :async, :omniauthable, 
    :omniauth_providers => [:google_oauth2]

  # === STANDARD DEVISE FIELDS === #

  ## Database authenticatable
  field :email,              type: String, :default => ""
  field :encrypted_password, type: String, :default => ""

  ## Recoverable
  field :reset_password_token,   type: String
  field :reset_password_sent_at, type: Time

  ## Rememberable
  field :remember_created_at, type: Time

  ## Trackable
  field :sign_in_count,      type: Integer, :default => 0
  field :current_sign_in_at, type: Time
  field :last_sign_in_at,    type: Time
  field :current_sign_in_ip, type: String
  field :last_sign_in_ip,    type: String

  ## Confirmable
  field :confirmation_token,   type: String
  field :confirmed_at,         type: Time
  field :confirmation_sent_at, type: Time
  field :unconfirmed_email,    type: String # Only if using reconfirmable

  ## Lockable
  field :failed_attempts, type: Integer, :default => 0 # Only if lock strategy is :failed_attempts
  field :unlock_token,    type: String # Only if unlock strategy is :email or :both
  field :locked_at,       type: Time

  ## Token authenticatable
  # field :authentication_token, :type => String

  # === CALLBACKS === #

  before_validation :update_caps_field
  before_validation :update_avatar_key
  before_create :set_signup_flags
  before_create :check_for_inactive_email
  after_create :convert_group_invitations
  before_save :update_identity_hash
  after_save :process_avatar
  before_update :process_email_change
  after_update :update_logs
  after_update :check_for_domain

  # === USER MOCK FIELD METHODS === #

  def user_url
    "#{ENV['root_url'] || 'https://www.badgelist.com'}/u/#{username_with_caps}"
  end

  # Returns URL of the specified version of this user's avatar (uses gravatar as a backup)
  # Valid version values are nil (defaults to full size), :medium, :small
  def avatar_image_url(version = nil)
    return_value = avatar_url(version) || gravatar_url(version)
  end
  def avatar_image_medium_url; avatar_url(:medium); end
  def avatar_image_small_url; avatar_url(:small); end

  # Returns URL of this user's gravatar (accepts same version values as avatar_image_url method)
  def gravatar_url(version = nil)
    email_temp = (email || 'nonexistentuser@example.com').downcase
    gravatar_id = Digest::MD5::hexdigest(email_temp)
    size_map = { nil => 500, medium: 200, small: 50 }
    "https://secure.gravatar.com/avatar/#{gravatar_id}?s=#{size_map[version]}&d=mm"
  end

  # JSON Template String Shortcuts
  def json_cu
    return json(:current_user).to_json
  end

  # Returns whether this user is on a private domain AND isn't added to the non-private list
  def is_private; has_private_domain && !is_non_private_domain_user; end
  def email_domain
    if email.blank? || !email.include?('@')
      nil
    else
      email.split('@')[1]
    end
  end

  # === CLASS METHODS === #

  # This will find by ObjectId OR by username
  def self.find(input)
    user = nil

    if input.to_s.match /^[0-9a-fA-F]{24}$/
      user = super rescue nil
    end

    if user.nil?
      user = User.find_by(username: input.to_s.downcase) rescue nil
    end

    user
  end

  def self.get_inactive_email_list
    inactive_email_list_item = InfoItem.find_by(key: INACTIVE_EMAIL_LIST_KEY) rescue nil
    (inactive_email_list_item) ? (inactive_email_list_item.data['emails'] || []) : []
  end

  # Call this method to track a bounce of the passed email address
  # If is_inactive is true this will block the email, otherwise it will track a bounce
  # and potentially block the email if it's over the limit.
  def self.track_bounce(email, is_inactive, bounced_at, bounce_id)
    # First query for the user and the inactive email list (and create the list if missing)
    user = User.find_by(email: email) rescue nil
    inactive_email_list_item = InfoItem.find_by(key: INACTIVE_EMAIL_LIST_KEY) rescue nil
    unless inactive_email_list_item
      inactive_email_list_item = InfoItem.new
      inactive_email_list_item.type = 'list'
      inactive_email_list_item.name = 'Inactive Email List'
      inactive_email_list_item.key = INACTIVE_EMAIL_LIST_KEY
      inactive_email_list_item.data = { 'emails' => [] }
      inactive_email_list_item.save
    end
    block_this_email = is_inactive
    groups_to_update = []

    # Now take the actions which are specific to whether or not there is a user record
    if user
      # First track the bounce count on the user record
      if user.last_email_bounce_at.nil? \
          || (user.last_email_bounce_at < (bounced_at - EMAIL_BOUNCE_MEMORY.days))
        # Then "forget" the bounces and overwrite the existing fields
        user.email_bounces = 1
        user.last_email_bounce_at = bounced_at
      else
        # Increment the bounce count and check if we're over the threshold
        user.email_bounces = (user.email_bounces || 0) + 1
        user.last_email_bounce_at = [bounced_at, user.last_email_bounce_at].max
        block_this_email ||= (user.email_bounces > MAX_EMAIL_BOUNCES)
      end

      # We'll log the bounce on all member and admin groups
      # NOTE FOR IMPROVEMENT: If they are in multiple groups this will result in duplicate info
      groups_to_update = Group.any_of(
        { :id.in => user.admin_of_ids },
        { :id.in => user.member_of_ids }
      )

      # Then set inactive details if needed
      user.inactive_email_bounce_id = bounce_id if is_inactive
      user.email_inactive = true if block_this_email
      
      user.save
    else
      # We'll log the bounce on all invitet member and admin groups
      groups_to_update = Group.any_of(
        { :invited_admins.elem_match => { :email => email } },
        { :invited_members.elem_match => { :email => email } }
      )
    end

    # Run through the groups that need updating
    groups_to_update.each do |group|
      group.log_bounced_email(email, bounced_at, is_inactive)
      group.timeless.save
    end

    # Finally add the current email to the inactive email list if needed
    if block_this_email && !inactive_email_list_item.data['emails'].include?(email)
      inactive_email_list_item.data['emails'] << email
      inactive_email_list_item.save
    end
  end

  # Call this method to unblock the passed email address
  # NOTE: Set include_postmark to attempt to activate bounce if there's a user record & bounce id
  def self.unblock_email(email, include_postmark = false)
    # First query for the user and the inactive email list (and create the list if missing)
    user = User.find_by(email: email) rescue nil
    inactive_email_list_item = InfoItem.find_by(key: INACTIVE_EMAIL_LIST_KEY) rescue nil
    unless inactive_email_list_item
      inactive_email_list_item = InfoItem.new
      inactive_email_list_item.type = 'list'
      inactive_email_list_item.name = 'Inactive Email List'
      inactive_email_list_item.key = INACTIVE_EMAIL_LIST_KEY
      inactive_email_list_item.data = { 'emails' => [] }
      inactive_email_list_item.save
    end
    
    # Next remove the current email from the inactive email list if needed
    if inactive_email_list_item.data['emails'].include? email
      inactive_email_list_item.data['emails'].delete email
      inactive_email_list_item.save
    end
    
    if user
      # First update postmark if needed
      if include_postmark && user.inactive_email_bounce_id
        begin
          postmark_client = Postmark::ApiClient.new(ENV['POSTMARK_API_KEY'])
          postmark_client.activate_bounce(user.inactive_email_bounce_id)
          user.inactive_email_bounce_id = nil
        rescue Exception => e
          logger.error "#=== User.unblock_email: Error unblocking #{email}. Error Msg: '#{e}'. ===#"
        end
      end
      
      # Set remaining fields and save
      user.email_inactive = false
      user.email_bounces = 0
      user.save
    end
  end

  # === ASYNC CLASS METHODS === #

  # Update the cached user details on all related logs
  def self.update_log_user_fields(user_id)
    user = User.find(user_id)
    user.logs.each do |log|
      log.update_user_fields_from user
      log.timeless.save
    end

    return user.logs.count
  end

  # === OMNIAUTH CLASS METHODS === #

  # This method will either find or create a new user account from the supplied omniauth auth hash
  # If an existing user is found it will be linked to this oauth identity and updated.
  def self.from_omniauth(auth)
    provider = auth.provider
    
    if provider == 'google_oauth2'
      uid_field = 'omniauth_google_oauth2_uid'
      hash_field = 'omniauth_google_oauth2_hash'
      
      uid = auth.uid
      email = auth.info.email.to_s.downcase
      name = auth.info.name
    end
    
    # Try to locate an existing user account
    user = User.where(email: email).first

    if user
      # Then update any fields that need updating and sign the user in
      user.omniauth_last_provider = provider
      user[uid_field] = uid
      user[hash_field] = auth.to_hash
      user.name ||= name
      user.email ||= email
      user.confirmed_at ||= Time.now # confirmation no longer needed

      user.save if user.changed?
    else
      # Then create a new user
      user = User.new
      user.name = name
      user.email = email
      user.username_with_caps = User.generate_unique_username_from(name)
      user.auto_username_needs_review = true # triggers a review screen on signin
      user.omniauth_last_provider = provider
      user[uid_field] = uid
      user[hash_field] = auth.to_hash # NOTE: The image information is pulled from this on save
      user.skip_confirmation!
      user.password = Devise.friendly_token[0,20]
      user.user_defined_password = false # Records the fact that the user doesn't know the password

      user.save
    end

    user
  end

  # This method accepts any string (such as 'John Doe, Ph.D.') and returns a value suitable for
  # saving into the 'username_with_caps' field. It ensures that the username doesn't already exist.
  def self.generate_unique_username_from(name_string, sep = '-')
    # First we parameterize the string (the code below is taken from the standard rails 
    # parameterize function except without downcasing at the end)
    username_with_caps = ActiveSupport::Inflector::transliterate(name_string)
    username_with_caps.gsub!(/[^a-zA-Z0-9\-_]+/, sep) # Turn unwanted chars into the separator
    unless sep.nil? || sep.empty?
      re_sep = Regexp.escape(sep)
      username_with_caps.gsub!(/#{re_sep}{2,}/, sep) # No more than one of the separator in a row.
      username_with_caps.gsub!(/^#{re_sep}|#{re_sep}$/, '') # Remove leading/trailing separator.
    end

    # Now make sure that we have a unique username
    root_username_with_caps = username_with_caps
    remaining_tries = 20 # this is how many times we'll try to generate a sequential name
    while (User.where(username: username_with_caps.downcase).count > 0) && (remaining_tries > 0)
      remaining_tries -= 1
      username_with_caps = root_username_with_caps + (20 - remaining_tries).to_s
    end

    if (remaining_tries == 0) && (User.where(username: username_with_caps.downcase).count > 0)
      # If we ran out of tries and we still couldn't find a unique name then append a random
      # five character alphanumeric string and assume success (1 in 60 million chance of failure).
      username_with_caps = root_username_with_caps + "#{sep}#{rand(36**5).to_s(36)}"
    end

    username_with_caps
  end

  # === DEVISE OVERRIDE CLASS METHODS === #

  # This method is called by RegistrationsController when building the blank user
  # We're overriding it in order to extract OmniAuth info that came from a failed SSO attempt
  def self.new_with_session(params, session)
    super.tap do |user|
      if data = session['devise.google_oauth2_data'] \
          && session['devise.google_oauth2_data']['extra']['raw_info']
        user.email = data['email'] if user.email.blank?
        user.name = data['name'] if user.name.blank?
      end
    end
  end

  # === INSTANCE METHODS === #

  def to_param
    username_with_caps
  end

  # Returns full URL to this user's profile based on current root URL
  def profile_url
    "#{ENV['root_url'] || 'https://www.badgelist.com'}/u/#{username_with_caps}"
  end

  # Updates last_active
  def log_activity(active_at = Time.now)
    if active_at.to_date > (last_active || Date.new)
      self.last_active = active_at.to_date
      self.timeless.save
    end
  end

  # Gets UI-ready list of cards that this user has added to stripe
  def stripe_card_options
    if stripe_cards.blank?
      []
    else
      stripe_cards.map do |card|
        ["#{card['brand']}: xxx-#{card['last4']}", card['id']]
      end
    end
  end

  # Gets UI-ready list of groups owned by this user
  # Accepts "except" option to exclude a particular list of ids
  def owned_group_options(options = {})
    return_list = []
    excluded_group_ids = options[:except] || []
    
    owned_groups.each do |group|
      return_list << [group.name, group.id] unless excluded_group_ids.include? group.id
    end

    return_list
  end

  # Gets UI-ready list of groups for which this user is an admin
  # Accepts "except" option to exclude a particular list of ids
  def admin_group_options(options = {})
    return_list = []
    excluded_group_ids = options[:except] || []
    
    admin_of.each do |group|
      return_list << [group.name, group.id] unless excluded_group_ids.include? group.id
    end

    return_list.sort_by{ |item| item.first }
  end

  def set_flag(flag)
    self.flags << flag unless flags.include? flag
  end

  def clear_flag(flag)
    self.flags.delete flag if flags.include? flag
  end

  def has_flag?(flag)
    flags.include? flag
  end

  # Returns boolean if the object is understood, otherwise returns nil
  def can_see?(some_record)
    if some_record.class == Entry
      return true # FIXME >> Build out the logic
    else
      return nil
    end
  end

  def member_of?(group)
    member_of_ids.include?(group.id)
  end

  def admin_of?(group)
    admin_of_ids.include?(group.id)
  end

  def member_or_admin_of?(group)
    member_of?(group) || admin_of?(group)
  end

  # Doesn't use any queries, returns :admin or :member or :none
  def member_type_of(group_id)
    if admin_of_ids.include? group_id
      :admin
    elsif member_of_ids.include? group_id
      :member
    else
      :none
    end
  end

  # Queries for all groups (admins and members) in no particular order.
  # If public_only is set then it will filter out groups based on admin & member visbility
  def groups(public_only = true)
    if public_only
      Group.any_of(
        {:id.in => member_of_ids, member_visibility: 'public'}, 
        {:id.in => admin_of_ids, admin_visibility: 'public'}
      )
    else
      Group.where(:id.in => [admin_of_ids, member_of_ids].flatten)
    end
  end

  # Pass the badge OR the id of the badge
  def learner_of?(badge_or_id)
    case badge_or_id.class.to_s
    when 'Badge'
      learner_badge_ids.include? badge_or_id.id
    when 'BSON::ObjectId'
      learner_badge_ids.include? badge_or_id
    when 'String'
      learner_badge_ids.include? BSON::ObjectId.from_string(badge_or_id)
    else
      throw "Invalid type #{badge_or_id.class.to_s} for badge_or_id. " \
        + "(Accepted types are Badge, ObjectId or String.)"
    end
  end

  # Pass the badge OR the id of the badge
  def expert_of?(badge_or_id)
    case badge_or_id.class.to_s
    when 'Badge'
      expert_badge_ids.include? badge_or_id.id
    when 'BSON::ObjectId'
      expert_badge_ids.include? badge_or_id
    when 'String'
      expert_badge_ids.include? BSON::ObjectId.from_string(badge_or_id)
    else
      throw "Invalid type #{badge_or_id.class.to_s} for badge_or_id. " \
        + "(Accepted types are Badge, ObjectId or String.)"
    end
  end

  # Pass the badge OR the id of the badge
  def learner_or_expert_of?(badge_or_id)
    learner_of?(badge_or_id) || expert_of?(badge_or_id)
  end

  def find_log(badge)
    logs.find_by(badge_id: badge.id) rescue nil
  end

  # Returns the date which this user's badge was issued (or nil if they are not an expert)
  def expert_date(badge)
    log = logs.find_by(badge_id: badge.id) rescue nil
    
    if log.nil? || log.detached_log
      nil
    else
      log.date_issued
    end
  end

  # Returns name surrounded by quotes and with double quotes replaced by single quotes
  def escaped_name
    '"' + name.gsub(/"/, "'") + '"'
  end

  # Returns "John Doe <email@example.com>" OR "email@example.com" depending on presence of name
  def email_name
    if name.blank?
      return email
    else
      return "#{escaped_name} <#{email}>"
    end
  end

  def expert_logs
    return logs.where(validation_status: 'validated')
  end

  # Returns all badge logs by group. Doesn't filter out anything.
  # If public_only then only gets expert logs, otherwise returns everything except detached logs.
  #
  # Return array has one entry for each group = {
  #   :type => one_of['Admin', 'Member'],
  #   :group => the_group,
  #   :badges => { [:badge,
  #                 :log]
  #              } }
  # >> Return array is sorted by group name
  def group_badge_log_list(public_only = true)
    badge_map, log_map = {}, {} # group_id => badges[], #badge_id => logs
    group_ids, badge_ids = [], []
    return_rows = []

    # First build the query

    # Get all expert logs which aren't hidden or detached
    if public_only 
      log_query = logs.where(validation_status: 'validated', show_on_profile: true, 
        detached_log: false)
    else
      log_query = logs.where(detached_log: false)
    end

    # Run through the log query and build the map
    log_query.each do |log|
      badge_ids << log.badge_id unless badge_ids.include? log.badge_id      
      log_map[log.badge_id] = log
    end

    Badge.where(:id.in => badge_ids).asc(:name).each do |badge|
      group_ids << badge.group_id unless group_ids.include? badge.group_id

      if badge_map.has_key? badge.group_id
        badge_map[badge.group_id] << badge
      else
        badge_map[badge.group_id] = [badge]
      end
    end

    Group.where(:id.in => group_ids).asc(:name).each do |group|
      group_row = {
        type: member_type_of(group.id).to_s.capitalize,
        group: group,
        badges: []
      }

      badge_map[group.id].each do |badge|
        badge_row = {
          badge: badge,
          log: log_map[badge.id]
        }

        group_row[:badges] << badge_row
      end

      return_rows << group_row
    end

    return_rows
  end

  def manually_update_identity_hash
    self.identity_salt = SecureRandom.hex
    self.identity_hash = 'sha256$' + Digest::SHA256.hexdigest(email + identity_salt)
  end

  # This updates domain cache related fields from domain.json(:for_user_cache)
  def update_domain_cache_from(domain_json)
    self.domain_id = domain_json[:id]
    self.has_private_domain = domain_json[:is_private]
    self.is_non_private_domain_user = \
      domain_json[:non_private_domain_user_ids].to_a.include? self.id
    self.visible_to_domain_urls = [domain_json[:url]]
    self.visible_to_domain_urls += domain_json[:visible_to_domain_urls]
  end
  
  def clear_domain_cache
    self.domain = nil
    self.has_private_domain = false
    self.is_non_private_domain_user = false
    self.visible_to_domain_urls = []
  end

  # === STRIPE RELATED METHODS === #

  def has_stripe_card?
    !stripe_customer_id.blank? && !stripe_cards.blank?
  end

  # Calls out to stripe to create a new customer record and then saves the strip cust id locally
  def create_stripe_customer
    if stripe_customer_id.blank?
      response = Stripe::Customer.create(
        email: email,
        description: "#{name} (#{username_with_caps})",
        metadata: {
          user_id: id,
          username: username,
          name: name
        }
      )
      
      if response
        self.stripe_customer_id = response.id
        self.save
      end
    end
  end

  # Calls out to stripe to add a card (the token comes from Stripe.js on the front end)
  # If async is set to true then the method will return the id of a poller
  def add_stripe_card(card_token, async = false)
    if async
      poller = Poller.new
      poller.save
      User.delay(queue: 'high', retry: false).add_stripe_card(card_token, user_id: id, \
        poller_id: poller.id)
      poller.id
    else
      User.add_stripe_card(card_token, user: self)
    end
  end

  # Calls out to stripe to add a card (the token comes from Stripe.js on the front end)
  # Accepts the following options
  # - user_id: Provide this to have the method query for the user
  # - user: Provide a pre-queried user object to save a query
  # - poller_id: If provided this poller record will be updated with success or failure details
  def self.add_stripe_card(card_token, options = {})
    begin
      poller = Poller.find(options[:poller_id]) rescue nil
      user = options[:user] || User.find(options[:user_id])

      user.create_stripe_customer if user.stripe_customer_id.blank?  
      customer = Stripe::Customer.retrieve(user.stripe_customer_id)
      card = customer.sources.create(source: card_token)

      if card
        user.stripe_default_source = customer.default_source
        user.stripe_cards << card.to_hash
        user.save

        if poller
          poller.status = 'successful'
          poller.message = 'You have successfully added a credit card to your account.'
          poller.data = card.to_hash
          poller.save
        end

        # Then update analytics
        IntercomEventWorker.perform_async({
          'event_name' => 'stripe-card-add',
          'email' => user.email,
          'created_at' => Time.now.to_i
        })
      else
        # Then update analytics
        IntercomEventWorker.perform_async({
          'event_name' => 'stripe-card-rejected',
          'email' => user.email,
          'created_at' => Time.now.to_i
        })

        throw "Card was rejected."
      end
    rescue Exception => e
      if poller
        poller.status = 'failed'
        poller.message = 'An error occurred while trying to add the credit card, ' \
          + "please try again. (Error message: #{e})"
        poller.save
      else
        throw e
      end
    end
  end

  # Calls out to stripe to refresh list of stripe cards
  def refresh_stripe_cards
    if stripe_customer_id.blank?
      self.stripe_cards = []
    else
      customer = Stripe::Customer.retrieve(stripe_customer_id)
      cards = customer.sources.all
      self.stripe_cards = cards.map{ |c| c.to_hash } if customer && cards
      self.stripe_default_source = customer.default_source
    end
    self.save
  end

  # Calls out to stripe to delete a card
  # If async is set to true then the method will return the id of a poller
  def delete_stripe_card(card_id, async = false)
    if async
      poller = Poller.new
      poller.save
      User.delay(queue: 'high', retry: false).delete_stripe_card(card_id, user_id: id, \
        poller_id: poller.id)
      poller.id
    else
      User.delete_stripe_card(card_id, user: self)
    end  
  end

  # Calls out to stripe to delete a card
  # Accepts the following options
  # - user_id: Provide this to have the method query for the user
  # - user: Provide a pre-queried user object to save a query
  # - poller_id: If provided this poller record will be updated with success or failure details
  def self.delete_stripe_card(card_id, options = {})
    begin
      poller = Poller.find(options[:poller_id]) rescue nil
      user = options[:user] || User.find(options[:user_id])

      customer = Stripe::Customer.retrieve(user.stripe_customer_id)
      card = customer.sources.retrieve(card_id)

      if card
        card.delete
        user.refresh_stripe_cards

        if poller
          poller.status = 'successful'
          poller.message = 'The credit card has been removed from your account.'
          poller.data = card.to_hash
          poller.save
        end

        # Then update analytics
        IntercomEventWorker.perform_async({
          'event_name' => 'stripe-card-delete',
          'email' => user.email,
          'created_at' => Time.now.to_i
        })
      else
        throw "There was a problem removing the card, please try again."
      end
    rescue Exception => e
      if poller
        poller.status = 'failed'
        poller.message = 'An error occurred while trying to remove the credit card, ' \
          + "please try again. (Error message: #{e})"
        poller.save
      else
        throw e
      end
    end
  end

protected

  def update_caps_field
    if username_with_caps.nil?
      self.username = nil
    else
      self.username = username_with_caps.downcase
    end
  end

  def update_avatar_key
    if new_record? || avatar_key_changed?
      self.direct_avatar.key = avatar_key
      self.processing_avatar = true
    end
  end

  def process_avatar
    if processing_avatar
      User.delay(queue: 'high', retry: 5).do_process_avatar(id)
    end
  end

  # Processes changes to the image from carrierwave direct key
  def self.do_process_avatar(user_id)
    user = User.find(user_id)
    user.processing_avatar = false

    if !user.direct_avatar.blank?
      user.remote_avatar_url = user.direct_avatar.direct_fog_url(with_path: true)
      
      if user.save
        # If it worked then update all of the related logs
        User.delay(queue: 'low').update_log_user_fields(user_id)
      else
        # If there was an error then clear out the uploaded image and use the default
        user.avatar_key = nil
        user.save! # This should trigger the callback again calling a new instance of this method
      end
    elsif user.omniauth_google_oauth2_hash && user.omniauth_google_oauth2_hash['info'] \
        && !user.omniauth_google_oauth2_hash['info']['image'].blank?
      # Use the image from their google profile if available
      user.remote_avatar_url = user.omniauth_google_oauth2_hash['info']['image']
      user.save!
    else
      # Use the default image
      user.remote_avatar_url = user.gravatar_url
      user.save!
    end
  end  

  # Sets one or more of the following flags: 
  #   invited-member, invited-admin, invited-learner, invited-expert, organic-signup
  def set_signup_flags
    self.flags = [] if flags.nil?
    is_organic = true

    Group.where(:invited_admins.elem_match => { :email => email }).entries.each do |group|
      set_flag 'invited-admin'
      is_organic = false

      invited_item = group.invited_admins.detect { |u| u["email"] == (email || unconfirmed_email) }
      set_flag 'invited-learner' unless invited_item["badges"].blank?
      set_flag 'invited-expert' unless invited_item["validations"].blank?
    end

    Group.where(:invited_members.elem_match => { :email => email }).entries.each do |group|
      set_flag 'invited-member'
      is_organic = false

      invited_item = group.invited_members.detect { |u| u["email"] == (email || unconfirmed_email) }
      set_flag 'invited-learner' unless invited_item["badges"].blank?
      set_flag 'invited-expert' unless invited_item["validations"].blank?
    end

    if is_organic
      set_flag 'organic-signup'
    end
  end

  def check_for_inactive_email
    if User.get_inactive_email_list.include? email
      self.email_inactive = true
    end
  end

  # Finds any references to this user's email in the invited_admins/users arrays on groups.
  # When found it upgrades the invitation to an actual relationship.
  def convert_group_invitations
    # First query for groups where we have been invited as an admin
    Group.where(:invited_admins.elem_match => { :email => email }).entries.each do |group|
      # First add group membership
      group.admins << self
      group.reload
      self.reload
      invited_item = group.invited_admins.detect { |u| u["email"] == (email || unconfirmed_email)}
      group.invited_admins.delete(invited_item) if invited_item
      group.save

      # Then add to any badges (as learner)
      group.badges.where(:url.in => invited_item["badges"]).each do |badge|
        badge.add_learner self
      end unless invited_item["badges"].blank?
      
      # Then add any validations
      invited_item["validations"].each do |v|
        badge = group.badges.find_by(url: v["badge"]) rescue nil
        validating_user = User.find(v["user"]) rescue nil
        summary, body = v["summary"], v["body"]

        unless badge.nil? || validating_user.nil? || summary.blank?
          log = badge.add_learner self # does nothing but return the log if already added as learner
          log.add_validation validating_user, summary, body, true
        end
      end unless invited_item["validations"].blank?
    end
    # Then query for groups where we have been invited as a normal member
    Group.where(:invited_members.elem_match => { :email => email }).entries.each do |group|
      # First add group membership
      group.members << self
      group.reload
      self.reload
      invited_item = group.invited_members.detect { |u| u["email"] == (email || unconfirmed_email)}
      group.invited_members.delete(invited_item) if invited_item
      group.save

      # Then update analytics
      IntercomEventWorker.perform_async({
        'event_name' => 'group-join',
        'email' => email,
        'created_at' => Time.now.to_i,
        'metadata' => {
          'group_id' => group.id.to_s,
          'group_name' => group.name,
          'group_url' => group.group_url,
          'join_type' => 'invited'
        }
      })

      # Then add to any badges (as learner)
      group.badges.where(:url.in => invited_item["badges"]).each do |badge|
        badge.add_learner self
      end unless invited_item["badges"].blank?

      # Then add any validations
      invited_item["validations"].each do |v|
        badge = group.badges.find_by(url: v["badge"]) rescue nil
        validating_user = User.find(v["user"]) rescue nil
        summary, body = v["summary"], v["body"]

        unless badge.nil? || validating_user.nil? || summary.blank?
          log = badge.add_learner self # does nothing but return the log if already added as learner
          log.add_validation validating_user, summary, body, true
        end
      end unless invited_item["validations"].blank?
    end
  end

  def update_identity_hash
    if email_changed?
      self.identity_salt = SecureRandom.hex
      self.identity_hash = 'sha256$' + Digest::SHA256.hexdigest(email + identity_salt)
    end
  end

  def process_email_change
    if email_changed?
      self.email_inactive = false
      self.email_bounces = 0
      self.last_email_bounce_at = nil
      self.inactive_email_bounce_id = nil
    end
  end

  # Updates the cached user info on related logs if needed
  def update_logs
    if name_changed? || username_with_caps_changed? || email_changed?
      User.delay(queue: 'low').update_log_user_fields(self.id)
    end
  end

  # Run before insert/update to check for existince of domain and then set the link if so
  def check_for_domain
    if new_record? || email_changed?
      matched_domain = Domain.where(url: email_domain).first

      # If this is an update the domain is changing then start by resetting the cache field
      if !new_record? && (matched_domain != domain)
        clear_domain_cache
      end

      # Now set the cache values for the new domain
      if matched_domain
        update_domain_cache_from matched_domain.json(:for_user_cache)
      end
    end
  end

end
