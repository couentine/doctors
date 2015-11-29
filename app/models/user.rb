class User
  include Mongoid::Document
  include Mongoid::Timestamps
  include JSONFilter

  # === CONSTANTS === #
  
  MIN_PASSWORD_LENGTH = 6 # Note: This is just for use in tests & not actually tied to anything
  MAX_NAME_LENGTH = 200
  MAX_USERNAME_LENGTH = 15
  JSON_FIELDS = [:name, :username, :username_with_caps]

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

  # === CUSTOM FIELDS & VALIDATIONS === #
  
  field :name,                          type: String
  field :username,                      type: String
  field :username_with_caps,            type: String
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

  field :identity_hash,                 type: String
  field :identity_salt,                 type: String

  field :stripe_customer_id,            type: String
  field :stripe_default_source,         type: String
  field :stripe_cards,                  type: Array, default: []

  field :expert_badge_ids,              type: Array, default: []
  field :learner_badge_ids,             type: Array, default: []
  field :all_badge_ids,                 type: Array, default: []

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
    :validatable, :confirmable, :lockable, :async

  # Setup accessible (or protected) attributes for your model
  attr_accessible :email, :name, :username_with_caps, :password, :password_confirmation, 
    :remember_me

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
  before_create :set_signup_flags
  before_create :check_for_inactive_email
  after_create :convert_group_invitations
  before_save :update_identity_hash
  before_update :process_email_change
  after_update :update_logs

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

  # === INSTANCE METHODS === #

  def to_param
    username_with_caps
  end

  # Returns full URL to this user's profile based on current root URL
  def profile_url
    "#{ENV['root_url'] || 'http://badgelist.com'}/u/#{username_with_caps}"
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

  def learner_of?(badge)
    learner_badge_ids.include? badge.id
  end

  def expert_of?(badge)
    expert_badge_ids.include? badge.id
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

end
