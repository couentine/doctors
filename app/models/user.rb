class User
  include Mongoid::Document
  include Mongoid::Timestamps
  include JSONFilter

  # === CONSTANTS === #
  
  MIN_PASSWORD_LENGTH = 6 # Note: This is just for use in tests & not actually tied to anything
  MAX_NAME_LENGTH = 200
  MAX_USERNAME_LENGTH = 15
  JSON_FIELDS = [:name, :username, :username_with_caps]

  # === RELATIONSHIP === #

  has_many :created_groups, inverse_of: :creator, class_name: "Group"
  has_many :created_badges, inverse_of: :creator, class_name: "Badge"
  has_many :logs, dependent: :destroy
  has_many :created_entries, inverse_of: :creator, class_name: "Entry"
  has_and_belongs_to_many :admin_of, inverse_of: :admins, class_name: "Group"
  has_and_belongs_to_many :member_of, inverse_of: :members, class_name: "Group"

  # === CUSTOM FIELDS & VALIDTIONS === #
  
  field :name,                type: String
  field :username,            type: String
  field :username_with_caps,  type: String
  field :flags,               type: Array, default: [], pre_processed: true
  field :flags,               type: Array, default: [], pre_processed: true
  field :admin,               type: Boolean, default: false
  field :page_views,          type: Hash, default: {}, pre_processed: true
  field :form_submissions,    type: Array
  field :last_active_at,      type: Time
  field :active_months,       type: Array

  field :identity_hash,       type: String
  field :identity_salt,       type: String

  validates :name, presence: true, length: { maximum: MAX_NAME_LENGTH }
  validates :username_with_caps, presence: true, length: { within: 2..MAX_USERNAME_LENGTH }, uniqueness:true,
            format: { with: /\A[\w-]+\Z/, message: "can only contain letters, numbers, dashes and underscores." }
  validates :username, presence: true, length: { within: 2..MAX_USERNAME_LENGTH }, uniqueness:true,
            format: { with: /\A[\w-]+\Z/, message: "can only contain letters, numbers, dashes and underscores." }

  
  # === DEVISE SETTINGS === #

  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :trackable, :validatable,
         :confirmable, :lockable

  # Setup accessible (or protected) attributes for your model
  attr_accessible :email, :name, :username_with_caps, :password, :password_confirmation, :remember_me

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
    username
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
    member_of.include?(group)
  end

  def admin_of?(group)
    admin_of.include?(group)
  end

  def learner_of?(badge)
    log = logs.find_by(badge: badge) rescue nil
    
    # Return value = 
    !log.nil? && !log.detached_log && log.validation_status != 'validated'
  end

  def expert_of?(badge)
    log = logs.find_by(badge: badge) rescue nil
    
    # Return value = 
    !log.nil? && !log.detached_log && log.validation_status == 'validated'
  end

  def find_log(badge)
    logs.find_by(badge: badge) rescue nil
  end

  # Returns the date which this user's badge was issued (or nil if they are not an expert)
  def expert_date(badge)
    log = logs.find_by(badge: badge) rescue nil
    
    if log.nil? || log.detached_log
      nil
    else
      log.date_issued
    end
  end

  # Returns "John Doe <email@example.com>" OR "email@example.com" depending on presence of name
  def email_name
    if name.blank?
      return email
    else
      return "#{name} <#{email}>"
    end
  end

  def expert_logs
    return logs.where(validation_status: 'validated')
  end

  # Returns all group AND badge memberships.
  # Filters out private groups if filter_user is not also a member
  # Return array has one entry for each group = {
  #   :type => :member/:admin,
  #   :group => the_group,
  #   :learner_logs => learner_logs_sorted_by_name[],
  #   :expert_logs => expert_logs_sorted_by_name[] }
  # >> Return array is sorted by group name
  def group_and_log_list(filter_user)
    # First go through and build a hash of all logs
    learner_log_map, expert_log_map = {}, {} # maps from group to array of logs
    logs.each do |log|
      target_map = (log.validation_status == 'validated') ? expert_log_map : learner_log_map
      if (log.badge != nil)                              \
          && (                                            \
            (filter_user == self)                          \
            || log.show_on_profile                          \
            || (filter_user                                  \
                && (filter_user.admin?                        \
                  || filter_user.member_of?(log.badge.group)   \
                  || filter_user.admin_of?(log.badge.group)     \
                )                                                \
            )                                                     \
          )
        if target_map.has_key?(log.badge.group)
          target_map[log.badge.group] << log
        else
          target_map[log.badge.group] = [log]
        end

      end
    end

    # Now build the return list
    the_list = []
    [{ groups: admin_of, type: :admin },
     { groups: member_of, type: :member }].each do |source|
      if !source[:groups].blank?
        source[:groups].each do |group|
          if (filter_user == self) || group.public? \
            || (filter_user && (filter_user.admin? \
              || group.has_member?(filter_user) || group.has_admin?(filter_user)))

            learner_logs = (learner_log_map.has_key?(group)) ? learner_log_map[group] : []
            expert_logs = (expert_log_map.has_key?(group)) ? expert_log_map[group] : []
            the_list  << { 
              :type => source[:type], 
              :group => group,
              :learner_logs => learner_logs.sort_by{ |log| log.badge.name },
              :expert_logs => expert_logs.sort_by{ |log| log.badge.name }
            }

          end
        end
      end
    end
    
    the_list.sort_by{ |item| item[:group].name }
  end

  def manually_update_identity_hash
    self.identity_salt = SecureRandom.hex
    self.identity_hash = 'sha256$' + Digest::SHA256.hexdigest(email + identity_salt)
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
