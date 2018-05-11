class User
  include Mongoid::Document
  include Mongoid::Timestamps
  include JSONFilter
  include JSONTemplater
  include AsyncCallbacks

  # === CONSTANTS === #
  
  TYPE_VALUES = ['individual', 'group']
  MIN_PASSWORD_LENGTH = 6 # Note: This is just for use in tests & not actually tied to anything
  MAX_NAME_LENGTH = 200
  MAX_USERNAME_LENGTH = 15
  MAX_JOB_TITLE_LENGTH = 50
  MAX_ORGANIZATION_NAME_LENGTH = 100
  MAX_WEBSITE_LENGTH = 100
  MAX_BIO_LENGTH = 300
  JSON_FIELDS = [:name, :username, :username_with_caps]
  JSON_MOCK_FIELDS = { :avatar_image_url => :avatar_image_url }

  JSON_TEMPLATES = {
    current_user: [:id, :name, :username, :username_with_caps, :admin, :email_inactive, :full_path, :email_verification_needed,
      :avatar_image_url, :avatar_image_medium_url, :avatar_image_small_url,  :learner_badge_count, :expert_badge_count,
      :async_callback_poller_id],
    group_list_item: [:id, :name, :username, :username_with_caps, :group_validation_request_counts,
      :avatar_image_url, :avatar_image_medium_url, :avatar_image_small_url, :full_path],
    intercom_user: [:name, { id: :user_id }, :email, :created_at, { username_with_caps: :username }, :profile_url, :flags, :admin, 
      :job_title, :organization_name, :website, :bio, :admin_group_count, :member_group_count, :learner_badge_count, :expert_badge_count],
    google_tag_manager: [:id, :name, { username_with_caps: :username }, :admin, :learner_badge_count, :expert_badge_count, 
      :member_group_count, :admin_group_count, :job_title, :organization_name ]
  }

  INACTIVE_EMAIL_LIST_KEY = 'postmark-inactive-emails'
  MAX_EMAIL_BOUNCES = 3
  EMAIL_BOUNCE_MEMORY = 14 # days
  HALF_OFF_FLAG = '50_percent_off'

  # === RELATIONSHIP === #

  belongs_to :proxy_group, inverse_of: :proxy_user, class_name: 'Group' # required if user type is `group`
  has_many :created_groups, inverse_of: :creator, class_name: 'Group'
  has_many :owned_groups, inverse_of: :owner, class_name: 'Group'
  has_many :created_badges, inverse_of: :creator, class_name: 'Badge'
  has_many :logs, dependent: :destroy
  has_many :created_entries, inverse_of: :creator, class_name: 'Entry'
  has_and_belongs_to_many :admin_of, inverse_of: :admins, class_name: 'Group'
  has_and_belongs_to_many :member_of, inverse_of: :members, class_name: 'Group'
  has_many :report_results, dependent: :destroy
  has_many :info_items, dependent: :destroy
  belongs_to :domain, inverse_of: :users, class_name: 'Domain' # don't ever set this manually,
  has_many :owned_domains, inverse_of: :owner, class_name: 'Domain'
  has_and_belongs_to_many :group_tags # DO NOT EDIT DIRECTLY: Use group_tag.add_users/remove_users
  has_many :authentication_tokens, dependent: :destroy, inverse_of: :user, class_name: 'AuthenticationToken'
  has_many :created_authentication_tokens, inverse_of: :creator, class_name: 'AuthenticationToken'

  # === CUSTOM FIELDS === #
  
  field :type,                              type: String, default: 'individual'
  field :name,                              type: String
  field :username,                          type: String
  field :username_with_caps,                type: String
  field :job_title,                         type: String
  field :organization_name,                 type: String
  field :website,                           type: String
  field :bio,                               type: String

  field :has_private_domain,                type: Boolean, default: false
  field :is_non_private_domain_user,        type: Boolean, default: false
  field :visible_to_domain_urls,            type: Array
  field :flags,                             type: Array, default: [], pre_processed: true
  field :admin,                             type: Boolean, default: false
  field :form_submissions,                  type: Array
  field :last_active,                       type: Date
  field :last_active_at,                    type: Time # RETIRED
  field :active_months,                     type: Array # RETIRED
  field :page_views,                        type: Hash # RETIRED
  field :email_inactive,                    type: Boolean, default: false
  field :email_bounces,                     type: Integer, default: 0
  field :last_email_bounce_at,              type: Time
  field :inactive_email_bounce_id,          type: Integer

  mount_uploader :direct_avatar,            S3DirectUploader
  mount_uploader :avatar,                   S3AvatarUploader
  field :avatar_key,                        type: String
  field :processing_avatar,                 type: Boolean

  field :identity_hash,                     type: String
  field :identity_salt,                     type: String

  field :stripe_customer_id,                type: String
  field :stripe_default_source,             type: String
  field :stripe_cards,                      type: Array, default: []

  field :all_badge_ids,                     type: Array, default: []
  field :learner_badge_ids,                 type: Array, default: []
  field :requested_badge_ids,               type: Array, default: []
  field :expert_badge_ids,                  type: Array, default: []
  field :group_validation_request_counts,   type: Hash, default: {} # key=group_id, value=count
  field :group_settings,                    type: Hash, default: {} # key=group_id, val=setting hash

  # OmniAuth Fields
  field :user_defined_password,             type: Boolean, default: true
  field :auto_username_needs_review,        type: Boolean, default: false
  field :omniauth_last_provider,            type: String
  field :omniauth_google_oauth2_uid,        type: String
  field :omniauth_google_oauth2_hash,       type: Hash # stores the full auth hash
  
  # LTI Fields
  field :lti_launch_hash,                   type: Hash # stores the most recent LTI launch params

  # === UNIVERSAL FIELD VALIDATIONS === #

  validates :type, inclusion: { in: TYPE_VALUES, message: "%{value} is not a valid User Type" }
  validates :name, presence: true, length: { maximum: MAX_NAME_LENGTH }
  validates :job_title, length: { maximum: MAX_JOB_TITLE_LENGTH }
  validates :organization_name, length: { maximum: MAX_ORGANIZATION_NAME_LENGTH }
  validates :bio, length: { maximum: MAX_BIO_LENGTH }
  validates :website, url: true, length: { maximum: MAX_WEBSITE_LENGTH }
  
  # === CONDITIONAL FIELD VALIDATIONS === #

  validates :proxy_group, if: :proxy_group_is_required?, presence: true
  validates :username_with_caps, unless: :username_is_required?, presence: false
  validates :username_with_caps, if: :username_is_required?, presence: true, length: { within: 2..MAX_USERNAME_LENGTH }, 
    uniqueness:true, format: { with: /\A[\w-]+\Z/, message: "can only contain letters, numbers, dashes and underscores." }
  validates :username, unless: :username_is_required?, presence: false
  validates :username, if: :username_is_required?, presence: true, length: { within: 2..MAX_USERNAME_LENGTH }, uniqueness:true,
    format: { with: /\A[\w-]+\Z/, message: "can only contain letters, numbers, dashes and underscores." }
  
  # === DEVISE SETTINGS === #

  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable, :registerable, :recoverable, :rememberable, :trackable, :validatable, :confirmable, :lockable, 
    :async, :omniauthable, omniauth_providers: [:google_oauth2]

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

  # === CALLBACKS === #

  before_validation :update_user_fields
  before_create :check_for_inactive_email
  before_save :update_identity_hash
  before_save :check_for_domain
  before_update :process_email_change
  after_update :update_logs
  after_update :push_stripe_field_changes
  after_destroy :clear_from_group_tags
  after_destroy :delete_from_intercom
  
  # === ASYNC CALLBACKS === #

  ASYNC_CALLBACKS = [
    :process_avatar,
    :convert_group_invitations_on_signup
  ]

  # === VALIDATION METHODS === #

  def proxy_group_is_required?
    return type == 'group'
  end

  def username_is_required?
    return type == 'individual'
  end

  # === USER MOCK FIELD METHODS === #

  def full_url; user_url; end
  def user_url
    "#{ENV['root_url'] || 'https://www.badgelist.com'}/u/#{username_with_caps}"
  end

  def full_path
    "/u/#{username_with_caps}"
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

  def email_verification_needed
    !self.confirmed? || self.pending_reconfirmation?
  end

  def admin_group_count
    (admin_of_ids || []).count
  end

  def member_group_count
    (member_of_ids || []).count
  end

  def learner_badge_count
    (learner_badge_ids || []).count
  end

  def expert_badge_count
    (expert_badge_ids || []).count
  end

  # JSON Template String Shortcuts
  def json_cu
    return json(:current_user).to_json
  end
  
  def email_domain
    if email.blank? || !email.include?('@')
      nil
    else
      email.split('@')[1]
    end
  end

  # This is used in intercom.rb to exclude certain users from intercom
  def show_in_intercom?
    !admin_of_ids.blank? || !created_group_ids.blank? || !owned_group_ids.blank?
  end

  def stripe_customer_url
    if stripe_customer_id.blank?
      nil
    else
      if ENV['stripe_livemode'] == 'true'
        "https://dashboard.stripe.com/customers/#{stripe_customer_id}"
      else
        "https://dashboard.stripe.com/test/customers/#{stripe_customer_id}"
      end
    end
  end

  # === CLASS METHODS === #

  # This will find by email OR by ObjectId OR by username
  def self.find(input)
    user = nil

    if input.to_s.include? '@'
      user = User.find_by(email: input.downcase) rescue nil
    elsif input.to_s.match /^[0-9a-fA-F]{24}$/
      user = super rescue nil
    end

    if user.nil?
      user = User.find_by(username: input.to_s.downcase) rescue nil
    end

    user
  end

  # Returns a string list of all inactive emails
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
        rescue => e
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

  def self.delete_from_intercom(email)
    intercom = Intercom::Client.new(token: ENV['INTERCOM_TOKEN'])
    intercom_user = intercom.users.find(email: email)
    intercom_user.delete if intercom_user
  end

  # === AUTHENTICATION CLASS METHODS === #

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
      # Then update any fields that need updating and disable email confirmation
      user.omniauth_last_provider = provider
      user[uid_field] = uid
      user[hash_field] = auth.to_hash
      user.name ||= name
      user.email ||= email
      if !user.confirmed? || user.pending_reconfirmation?
        user.confirm
      end

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
      user.skip_reconfirmation! # For some reason this is now needed
      user.password = Devise.friendly_token[0,20]
      user.user_defined_password = false # Records the fact that the user doesn't know the password

      user.save
    end

    user
  end

  # This method will either find or create a new user account from the supplied LTI launch hash.
  # It will also make sure that they have been added as a group member (or are already an admin).
  # WILL RAISE ArgumentError if email or full name is missing from the launch params.
  def self.from_lti(launch_params, add_to_group)
    # First pull out the key fields from the launch params
    email = launch_params['lis_person_contact_email_primary']
    name = launch_params['lis_person_name_full']

    if email.present? && name.present? 
      # Try to locate an existing user account
      user = User.where(email: email.downcase).first

      if user
        # Then update any fields that need updating and disable email confirmation
        user.lti_launch_hash = launch_params
        user.name ||= name
        user.email ||= email
        if !user.confirmed? || user.pending_reconfirmation?
          user.confirm
        end

        user.save if user.changed?
      else
        # Then create a new user
        user = User.new
        user.name = name
        user.email = email
        user.username_with_caps = User.generate_unique_username_from(name)
        user.auto_username_needs_review = true # triggers a review screen on signin
        user.lti_launch_hash = launch_params
        user.skip_confirmation!
        user.skip_reconfirmation! # For some reason this is now needed
        user.password = Devise.friendly_token[0,20]
        user.user_defined_password = false # Records the fact that the user doesn't know the pass

        user.save
      end

      # Now we add the user to the group if needed
      if add_to_group && !user.member_of?(add_to_group) && !user.admin_of?(add_to_group)
        add_to_group.members << user
        user.initialize_group_settings_for(add_to_group)
        user.save
      end

      user
    else
      raise ArgumentError.new('The LTI link you have followed is missing the name and email ' \
        + 'fields. Those fields are required for compatibility with Badge List. ' \
        + 'Please contact your site administrator.')
    end
  end

  # This method accepts any string (such as 'John Doe, Ph.D.') and returns a value suitable for saving into the 'username_with_caps' field. 
  # It ensures that the username doesn't already exist and that the username isn't too long to fit in the field.
  def self.generate_unique_username_from(name_string, sep = '-')
    max_root_length = MAX_USERNAME_LENGTH

    # First calculate a root username that fits in the full character limit and see if it is already taken
    username = User.root_username_from_name(name_string, max_root_length, sep)
    if User.where(username: username.downcase).count > 0
      # It is already taken so we will try STRATEGY 1 (appending a one or two digit number).
      # This strategy requires up to two characters of space at the end of the string so we may need to recalculate the root username.
      root_username = username
      max_root_length = MAX_USERNAME_LENGTH - 2
      if root_username.length > max_root_length
        root_username = User.root_username_from_name(name_string, max_root_length, sep)
      end

      # Now that we have at least 2 characters of space at the end, we will try the numbers from 1 to 20
      remaining_tries = 20 # this is how many times we'll try to generate a sequential name
      while (User.where(username: username.downcase).count > 0) && (remaining_tries > 0)
        remaining_tries -= 1
        username = root_username + (20 - remaining_tries).to_s
      end

      if (remaining_tries == 0) && (User.where(username: username.downcase).count > 0)
        # If we ran out of tries didn't succeed we try STRATEGY 2 (append random five character alphanumeric string).
        # This strategy has a 1 in 60 million chance of failure, so we assume success and do not try any more strategies.
        # This strategy requires 5 characters of space at the end of the string so we may need to recalculate the root username.
        max_root_length = MAX_USERNAME_LENGTH - 5
        if root_username.length > max_root_length
          root_username = User.root_username_from_name(name_string, max_root_length, sep)
        end
        username = root_username + rand(36**5).to_s(36)
      end
    end

    return username
  end

  # Returns a root username string which fits in the defined max_root_length. Will use various strategies to pick a pleasing name.
  def self.root_username_from_name(name_string, max_root_length, sep = '-')
    # Remove non western characters
    cleaned_name_string = ActiveSupport::Inflector::transliterate(name_string)

    # First try to dash case
    root_username = cleaned_name_string.gsub(/[^a-zA-Z0-9\-_]+/, sep)
    unless sep.nil? || sep.empty?
      re_sep = ::Regexp.escape(sep)
      root_username.gsub!(/#{re_sep}{2,}/, sep) # No more than one of the separator in a row.
      root_username.gsub!(/^#{re_sep}|#{re_sep}$/, '') # Remove leading/trailing separator.
    end

    # Now make sure we are under the character limit, if not, iterate until we are
    while root_username.length > max_root_length
      if root_username.include?(sep)
        # If we're overlimit, first we try to go to camel case instead of dash case
        root_username = cleaned_name_string.titlecase.gsub(/[^a-zA-Z]+/, '')
      elsif root_username[/[A-Za-z][A-Z][a-z]*$/].present?
        # If there are any extra words or initials on the end (not counting the first word) then we will clip them off
        # NOTE that regex in the condition includes the character before the pattern we are removing in order to not erase the whole string
        root_username.sub!(/[A-Z][a-z]*$/, '')
      else
        # Their first name itself is too long, so we just trim it
        root_username = root_username.first(max_root_length)
      end
    end

    return root_username
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
    username_with_caps || id.to_s
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

  def member_of?(group_or_id)
    case group_or_id.class.to_s
    when 'Group'
      member_of_ids.include?(group_or_id.id)
    when 'BSON::ObjectId'
      member_of_ids.include?(group_or_id)
    when 'String'
      member_of_ids.include?(BSON::ObjectId.from_string(group_or_id))
    else
      throw "Invalid type #{group_or_id.class.to_s} for group_or_id. (Accepted types are Group, ObjectId or String.)"
    end
  end

  def admin_of?(group_or_id)
    case group_or_id.class.to_s
    when 'Group'
      (proxy_group_id == group_or_id.id) || admin_of_ids.include?(group_or_id.id)
    when 'BSON::ObjectId'
      (proxy_group_id == group_or_id) || admin_of_ids.include?(group_or_id)
    when 'String'
      (proxy_group_id.to_s == group_or_id) || admin_of_ids.include?(BSON::ObjectId.from_string(group_or_id))
    else
      throw "Invalid type #{group_or_id.class.to_s} for group_or_id. (Accepted types are Group, ObjectId or String.)"
    end
  end

  def member_or_admin_of?(group_or_id)
    member_of?(group_or_id) || admin_of?(group_or_id)
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
      throw "Invalid type #{badge_or_id.class.to_s} for badge_or_id. (Accepted types are Badge, ObjectId or String.)"
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
      throw "Invalid type #{badge_or_id.class.to_s} for badge_or_id. (Accepted types are Badge, ObjectId or String.)"
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

  # Returns all badge logs by group.
  # If public_only then only gets expert logs, otherwise returns everything except detached logs.
  # If public_only then this will filter out groups with show_on_profile setting = false.
  # Set only_from_groups to an array of downcased group urls to only return logs from those groups.
  #
  # Return array has one entry for each group = {
  #   :type => one_of['Admin', 'Member'],
  #   :group => the_group,
  #   :show_on_profile => show_on_profile_value_from_group_settings,
  #   :badges => { [:badge,
  #                 :log]
  #              } }
  # >> Return array is sorted by group name
  def group_badge_log_list(public_only = true, only_from_groups = [])
    badge_map, log_map = {}, {} # group_id => badges[], #badge_id => logs
    group_ids, badge_ids = [], []
    return_rows = []
    show_on_profile = nil

    # First build the query

    # Get all expert logs which aren't hidden or detached
    if public_only 
      log_query = logs.where(validation_status: 'validated', show_on_profile: true, 
        detached_log: false)
    else
      log_query = logs.where(detached_log: false)
    end

    # Now add a group filter if needed
    if !only_from_groups.blank?
      # log_query = log_query.where() >> LEFT OF HERE: Next step is to build it out so that 
      #     the groups are pre-queried in this case. I need to count the queries in the page before
      #     so that I can make sure I'm not adding a query. And I need to not incluce blank groups.
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
      show_on_profile = get_group_settings_for(group)['show_on_profile']

      if show_on_profile || !public_only
        group_row = {
          type: member_type_of(group.id).to_s.capitalize,
          group: group,
          show_on_profile: show_on_profile,
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
    end

    return_rows
  end

  # This recalculates the appropriate key of group_validation_request_counts
  # Then if needed it will update all related group tags
  # NOTE: This is resource intensive and only designed to be called from other asynch methods
  def update_validation_request_count_for(group)
    new_count = \
      logs.where(:badge_id.in => group.badges_cache.keys, validation_status: 'requested').count
    
    if !self.group_validation_request_counts.has_key?(group.id.to_s) \
        || (self.group_validation_request_counts[group.id.to_s] != new_count)
      self.group_validation_request_counts[group.id.to_s] = new_count
      
      # Now update all of the group tags
      related_group_tags = group_tags.where(group: group.id)
      related_group_tags.each do |group_tag|
        group_tag.update_validation_request_count_for(self)
        group_tag.timeless.save
      end
    end
  end

  # Returns the group settings hash for this group (or returns defaults if no hash is found)
  # Pass the group id in order to save a potential query
  def get_group_settings_for(group_or_group_id)
    if (group_or_group_id.class == Group)
      group_id_string = group_or_group_id.id.to_s
    else # is either Id or String (or the consumer of the function is confused)
      group_id_string = group_or_group_id.to_s
    end

    group_settings[group_id_string] || { 'show_on_badges' => true, 'show_on_profile' => true }
  end

  # Sets appropriate key of group_settings to defaults or does nothing if values are already set.
  # Pass the group id in order to save a potential query
  def initialize_group_settings_for(group_or_group_id)
    if (group_or_group_id.class == Group)
      group_id_string = group_or_group_id.id.to_s
    else # is either Id or String (or the consumer of the function is confused)
      group_id_string = group_or_group_id.to_s
    end

    if group_settings[group_id_string].nil?
      self.group_settings[group_id_string] = { 'show_on_badges' => true, 'show_on_profile' => true }
    end
  end

  # This creates or updates the appropriate key of group_settings with the setting values provided
  # This method will also trigger the update of child logs as needed
  # NOTE: This method does not commit the save
  def update_group_settings_for(group, show_on_badges, show_on_profile)
    # First determine if this update represents a change
    show_on_badges_changed = show_on_badges != get_group_settings_for(group)['show_on_badges']
    show_on_profile_changed = show_on_profile != get_group_settings_for(group)['show_on_profile']
    settings_changed = show_on_badges_changed || show_on_profile_changed

    # Then update the settings
    self.group_settings[group.id.to_s] = {
      show_on_badges: show_on_badges,
      show_on_profile: show_on_profile,
    }

    # Then queue the log update if needed
    if settings_changed
      logs.where(:badge_id.in => group.badge_ids, detached_log: false).each do |log|
        log.show_on_badge = show_on_badges
        log.show_on_profile = show_on_profile
        log.timeless.save if log.changed?
      end
    end
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

  # === DOMAIN-RELATED METHODS === #

  # Return value is in ['none', 'public', 'private', 'private-excluded']
  def domain_membership
    if domain_id.blank?
      'none'
    elsif !has_private_domain
      'public'
    elsif is_non_private_domain_user
      'private-excluded'
    else
      'private'
    end 
  end

  # Returns whether this user is on a private domain AND isn't added to the non-private list
  def is_private; domain_membership == 'private'; end

  # Returns boolean indicating whether current_user can see this user's domain
  # Returns false if there is no domain
  def domain_visible_to(current_user)
    !domain_id.blank? && \
      (current_user.present? && (current_user.admin? || visible_to_domain_urls.include?(current_user.email_domain)))
  end

  # Returns boolean indicating whether current_user can see this user's profile
  def profile_visible_to(current_user)
    if is_private
      current_user.present? && ((self.id == current_user.id) || domain_visible_to(current_user))
    else
      true
    end
  end

  # === STRIPE RELATED METHODS === #

  def has_stripe_card?
    !stripe_customer_id.blank? && !stripe_cards.blank?
  end

  # Use this to generate the hash which gets set as the metadata property of the user's stripe customer record.
  # NOTE: If adding new metadata to this method, be sure to also update stripe_customer_metadata_changed? below.
  def stripe_customer_metadata
    {
      user_id: id,
      username: username,
      name: name
    }
  end

  # Generates the value used for the standard customer `description` field in Stripe.
  # NOTE: If adding new metadata to this method, be sure to also update stripe_customer_metadata_changed? below.
  def stripe_customer_description
    "#{name} (#{username_with_caps})"
  end

  # Use this determine if stripe needs to be updated with changes to stripe_customer_metadata, stripe_customer_description or email
  def stripe_customer_fields_changed?
    username_with_caps_changed? || name_changed? || email_changed?
  end

  # This updates stripe with a refreshed copy of stripe_customer_metadata, stripe_customer_description and email
  def self.push_fields_to_stripe(user_id)
    begin
      user = User.find(user_id)

      if user.stripe_customer_id.present?
        customer = Stripe::Customer.retrieve(user.stripe_customer_id)
        customer.email = user.email if customer.email != user.email
        customer.description = user.stripe_customer_description if customer.description != user.stripe_customer_description
        customer.metadata = user.stripe_customer_metadata
        customer.save
      end
    rescue => e
      if user
        # Log this error
        user.info_items.new(
          type: 'stripe-error',
          name: 'Problem Pushing Metadata to Stripe (User.push_fields_to_stripe)',
          data: { error: e.to_s }
        ).save
      else
        # No group so just throw the error
        throw e
      end
    end
  end

  # Calls out to stripe to create a new customer record and then saves the strip cust id locally
  def create_stripe_customer
    if stripe_customer_id.blank?
      customer = Stripe::Customer.create(
        email: email,
        description: stripe_customer_description,
        metadata: stripe_customer_metadata
      )
      
      if customer
        self.stripe_customer_id = customer.id
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
          'user_id' => user.id.to_s,
          'created_at' => Time.now.to_i
        })
      else
        # Then update analytics
        IntercomEventWorker.perform_async({
          'event_name' => 'stripe-card-rejected',
          'email' => user.email,
          'user_id' => user.id.to_s,
          'created_at' => Time.now.to_i
        })

        throw "Card was rejected."
      end
    rescue => e
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
          'user_id' => user.id.to_s,
          'created_at' => Time.now.to_i
        })
      else
        throw "There was a problem removing the card, please try again."
      end
    rescue => e
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

  def update_user_fields
    if username_with_caps.nil?
      self.username = nil
    else
      self.username = username_with_caps.downcase
    end

    if new_record? || avatar_key_changed?
      self.direct_avatar.key = avatar_key
      self.processing_avatar = true
    end

    if (type == 'group') & proxy_group_id.present?
      self.email = "#{proxy_group.url}@groups.badgelist.com"
      self.password = Devise.friendly_token(40) # randomize the password every time the record is touched, it should never be used
      self.user_defined_password = false
      self.name = proxy_group.name
    end
  end

  def check_for_inactive_email
    if User.get_inactive_email_list.include? email
      self.email_inactive = true
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

  # Makes async to group tag clearing method
  def clear_from_group_tags
    GroupTag.delay(queue: 'low').clear_deleted_user_from_all(self.id)
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

  # Called after an update (not on insert) to check if stripe customer field need updating
  def push_stripe_field_changes
    if stripe_customer_id.present? && stripe_customer_fields_changed?
      User.delay_for(30.seconds, queue: 'low', retry: false).push_fields_to_stripe(id)
    end
  end

  def delete_from_intercom
    User.delay(queue: 'low').delete_from_intercom(email)
  end

  # === ASYNC CALLBACK METHODS === #

  def convert_group_invitations_on_signup?
    _id_changed? \
      && (Group.any_of(
        { :invited_members.elem_match => { :email => (email || unconfirmed_email) } },
        { :invited_admins.elem_match => { :email => (email || unconfirmed_email) } }
      ).count > 0)
  end

  # Finds any references to this user's email in the invited_admins/users arrays on groups and adds them.
  # PERFORMANCE NOTE: The add_leaner calls should be refactored a bit because as written they end up firing the log.update_user method once
  #   for each badge invitation. Since that method then calls user.update_validation_request_count_for, it's all very inefficient. But it's
  #   only a huge performance hit if there are tons of invitations so skipping for now. Note that it is important that this all happen
  #   synchronously (or via poller) so the user is immediately presented with their correct memberships.
  def convert_group_invitations_on_signup!
    badge_map = {} # badge_url => badge
    log_map = {} # badge_url => log
    user_map = {} # id => user
    unqueried_user_ids = nil
    is_admin = false
    email_address = email || unconfirmed_email

    groups_to_join = Group.any_of(
      { :invited_members.elem_match => { :email => email_address } },
      { :invited_admins.elem_match => { :email => email_address } }
    )

    groups_to_join.each do |group|
      badge_map = {}
      log_map = {}
      is_admin = group.invited_admins.select{ |item| item['email'] == email }.present?

      # Add as an admin or member and clear the invitation
      if is_admin
        group.admins << self
        invited_item = group.invited_admins.detect { |u| u["email"] == email_address }
        group.invited_admins.delete(invited_item)
      else
        group.members << self
        invited_item = group.invited_members.detect { |u| u["email"] == email_address }
        group.invited_members.delete(invited_item)
      end
      group.timeless.save
      
      initialize_group_settings_for(group)

      IntercomEventWorker.perform_async({
        'event_name' => 'group-join',
        'email' => email_address,
        'user_id' => id.to_s,
        'created_at' => Time.now.to_i,
        'metadata' => {
          'group_id' => group.id.to_s,
          'group_name' => group.name,
          'group_url' => group.group_url,
          'join_type' => 'invited'
        }
      })

      badge_urls_to_join = (                                                 \
        (invited_item['badges'] || [])                                        \
        + (invited_item['validations'] || []).map{ |item| item['badge'] }     \
      ).uniq

      if badge_urls_to_join.present?
        group.badges.where(:url.in => badge_urls_to_join).each do |badge|
          badge_map[badge.url] = badge
          log = badge.add_learner(self) # NOTE: This could be rewritten (refer to PERFORMANCE NOTE above)
          log_map[badge.url] = log
        end
      end

      if invited_item['validations'].present?
        unqueried_user_ids = invited_item['validations'].map{ |item| item['user'] }.uniq - user_map.keys
        if unqueried_user_ids.present?
          User.where(:id.in => unqueried_user_ids).each do |user|
            user_map[user.id.to_s] = user
          end
        end

        invited_item['validations'].each do |validation_item|
          badge = badge_map[validation_item['badge']]
          log = log_map[validation_item['badge']]
          validating_user = user_map[validation_item['user'].to_s]
          summary = validation_item['summary']
          body = validation_item['body']
          preserve_body_html = (validation_item['preserve_body_html'] == true)

          if badge.present? && log.present? && validating_user.present? && summary.present?
            log.add_validation(validating_user, summary, body, true, true, preserve_body_html)
          end
        end
      end # if invited_item['validations'].present?
    end # groups_to_join loop

    # Finally we overwrite the badge id lists, just in case they got messed up
    self.all_badge_ids = logs.map{ |log| log.badge_id }
    self.expert_badge_ids = expert_logs.map{ |log| log.badge_id }
    self.learner_badge_ids = all_badge_ids - expert_badge_ids
  end

  def process_avatar?
    processing_avatar
  end

  # Processes changes to the image from carrierwave direct key
  def process_avatar!
    self.processing_avatar = false

    if direct_avatar.present?
      self.remote_avatar_url = direct_avatar.direct_fog_url(with_path: true)
      
      if self.save
        # If it worked then update all of the related logs
        if logs.count > 0
          User.delay(queue: 'low').update_log_user_fields(id) # put this in a new thread because it's not immediately critical to the UI
        end
      else
        # If there was an error then clear out the uploaded image and use the default
        self.remote_avatar_url = gravatar_url
        self.save!
      end
    elsif omniauth_google_oauth2_hash && omniauth_google_oauth2_hash['info'] && omniauth_google_oauth2_hash['info']['image'].present?
      # Use the image from their google profile if available
      self.remote_avatar_url = omniauth_google_oauth2_hash['info']['image']
      self.save!
    elsif lti_launch_hash.present? && lti_launch_hash['user_image'].present?
      # Use the image from their LTI profile if available
      self.remote_avatar_url = lti_launch_hash['user_image']
      self.save!
    else
      # Use the default image
      self.remote_avatar_url = gravatar_url
      self.save!
    end
  end  

end
