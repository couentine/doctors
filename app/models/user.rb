class User
  include Mongoid::Document
  include Mongoid::Timestamps
  include JSONFilter

  # === CONSTANTS === #
  
  MIN_PASSWORD_LENGTH = 6 # Note: This is just for use in tests & not actually tied to anything
  MAX_NAME_LENGTH = 200
  MAX_USERNAME_LENGTH = 15
  JSON_FIELDS = [:name, :username, :username_with_caps]

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

  field :identity_hash,                 type: String
  field :identity_salt,                 type: String

  field :stripe_customer_id,            type: String
  field :stripe_default_source,         type: String
  field :stripe_cards,                  type: Array, default: []

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
  after_create :convert_group_invitations
  before_save :update_identity_hash

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
    log = logs.find_by(badge_id: badge.id) rescue nil
    
    # Return value = 
    !log.nil? && !log.detached_log && log.validation_status != 'validated'
  end

  def expert_of?(badge)
    log = logs.find_by(badge_id: badge.id) rescue nil
    
    # Return value = 
    !log.nil? && !log.detached_log && log.validation_status == 'validated'
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
      else
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

        unless badge.nil? || validating_user.nil? || summary.blank? || body.blank?
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

      # Then add to any badges (as learner)
      group.badges.where(:url.in => invited_item["badges"]).each do |badge|
        badge.add_learner self
      end unless invited_item["badges"].blank?

      # Then add any validations
      invited_item["validations"].each do |v|
        badge = group.badges.find_by(url: v["badge"]) rescue nil
        validating_user = User.find(v["user"]) rescue nil
        summary, body = v["summary"], v["body"]

        unless badge.nil? || validating_user.nil? || summary.blank? || body.blank?
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

end
