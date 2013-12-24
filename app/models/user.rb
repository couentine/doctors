class User
  include Mongoid::Document
  include Mongoid::Timestamps

  # === CONSTANTS === #
  
  MIN_PASSWORD_LENGTH = 6 # Note: This is just for use in tests & not actually tied to anything
  MAX_NAME_LENGTH = 200
  MAX_USERNAME_LENGTH = 15

  # === RELATIONSHIP === #

  has_many :created_groups, inverse_of: :creator, class_name: "Group", dependent: :nullify
  has_many :created_badges, inverse_of: :creator, class_name: "Badge", dependent: :nullify
  has_and_belongs_to_many :admin_of, inverse_of: :admins, class_name: "Group"
  has_and_belongs_to_many :member_of, inverse_of: :members, class_name: "Group"

  # === CUSTOM FIELDS & VALIDTIONS === #
  
  field :name,                :type => String
  field :username,            :type => String

  validates :name, presence: true, length: { maximum: MAX_NAME_LENGTH }
  validates :username, presence: true, length: { within: 3..MAX_USERNAME_LENGTH }, uniqueness:true,
            format: { with: /\A[\w-]+\Z/, message: "can't have special characters." }

  
  # === DEVISE SETTINGS === #

  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :trackable, :validatable,
         :confirmable, :lockable

  # Setup accessible (or protected) attributes for your model
  attr_accessible :email, :name, :username, :password, :password_confirmation, :remember_me

  # === STANDARD DEVISE FIELDS === #

  ## Database authenticatable
  field :email,              :type => String, :default => ""
  field :encrypted_password, :type => String, :default => ""

  ## Recoverable
  field :reset_password_token,   :type => String
  field :reset_password_sent_at, :type => Time

  ## Rememberable
  field :remember_created_at, :type => Time

  ## Trackable
  field :sign_in_count,      :type => Integer, :default => 0
  field :current_sign_in_at, :type => Time
  field :last_sign_in_at,    :type => Time
  field :current_sign_in_ip, :type => String
  field :last_sign_in_ip,    :type => String

  ## Confirmable
  field :confirmation_token,   :type => String
  field :confirmed_at,         :type => Time
  field :confirmation_sent_at, :type => Time
  field :unconfirmed_email,    :type => String # Only if using reconfirmable

  ## Lockable
  field :failed_attempts, :type => Integer, :default => 0 # Only if lock strategy is :failed_attempts
  field :unlock_token,    :type => String # Only if unlock strategy is :email or :both
  field :locked_at,       :type => Time

  ## Token authenticatable
  # field :authentication_token, :type => String

  # === CALLBACKS === #

  after_create :convert_group_invitations

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

  def member_of?(group)
    self.member_of.include?(group)
  end

  def admin_of?(group)
    self.admin_of.include?(group)
  end

  # Returns "John Doe <email@example.com>" OR "email@example.com" depending on presence of name
  def email_name
    if self.name.blank?
      return email
    else
      return "#{name} <#{email}>"
    end
  end

  # Returns all groups for which this user is an admin OR a member
  # Returns list of hashes = { :type => :member/:admin, :group => the_group }
  def group_list
    the_list = []

    self.admin_of.each do |group|
      the_list  << { :type => :admin, :group => group }
    end unless self.admin_of.blank?
    self.member_of.each do |group|
      the_list  << { :type => :member, :group => group }
    end unless self.member_of.blank?
    
    the_list.sort_by{ |item| item[:group].name }
  end


  protected

    # Finds any references to this user's email in the invited_admins/users arrays on groups.
    # When found it upgrades the invitation to an actual relationship.
    def convert_group_invitations
      # First query for groups where we have been invited as an admin
      Group.where(:invited_admins.elem_match => { :email => self.email }).entries.each do |group|
        group.admins << self
        invited_item = group.invited_admins.detect { |u| u[:email] == self.email}
        group.invited_admins.delete(invited_item) if invited_item
        group.save!
      end
      # Then query for groups where we have been invited as a normal member
      Group.where(:invited_members.elem_match => { :email => self.email }).entries.each do |group|
        group.members << self
        invited_item = group.invited_members.detect { |u| u[:email] == self.email}
        group.invited_members.delete(invited_item) if invited_item
        group.save!
      end
    end

end
