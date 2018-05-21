#==========================================================================================================================================#
# 
# APP MODEL
# 
# Do not manage apps directly from the model, use the following decorators:
# - Use AppChangeDecorator to create, modify and delete an app.
# - Use AppMembershipDecorator to manage member users and groups.
# 
#==========================================================================================================================================#

class App
  include Mongoid::Document
  include Mongoid::Timestamps
  
  # === CONSTANTS === #

  STATUS_VALUES = ['active', 'inactive']
  REVIEW_STATUS_VALUES = ['pending', 'approved', 'disabled']
  TYPE_VALUES = ['free', 'paid', 'private']
  MAX_NAME_LENGTH = 50
  MAX_SLUG_LENGTH = 30

  # === RELATIONSHIPS === #

  belongs_to :owner,                      inverse_of: :owned_apps,            class_name: 'User'
  has_one :proxy_user,                    inverse_of: :proxy_app,             class_name: 'User'
  
  has_many :user_memberships,             class_name: 'AppUserMembership',    dependent: :delete
  has_and_belongs_to_many :users
  has_and_belongs_to_many :pending_users, inverse_of: :pending_apps,          class_name: 'User'
  has_and_belongs_to_many :member_users,  inverse_of: :member_of_apps,        class_name: 'User'
  has_and_belongs_to_many :admin_users,   inverse_of: :admin_of_apps,         class_name: 'User'
  has_and_belongs_to_many :disabled_users,inverse_of: :disabled_apps,         class_name: 'User'
 
  has_many :group_memberships,            class_name: 'AppGroupMembership',   dependent: :delete
  has_and_belongs_to_many :groups

  # === FIELDS === #

  field :status,                          type: String, default: 'active'
  field :review_status,                   type: String, default: 'approved'
  field :name,                            type: String
  field :slug,                            type: String
  field :type,                            type: String

  field :summary,                         type: String
  field :description,                     type: String
  field :organization,                    type: String
  field :website,                         type: String
  field :email,                           type: String

  mount_uploader :direct_image,           S3DirectUploader
  mount_uploader :image,                  S3BadgeUploader
  field :image_key,                       type: String
  field :processing_image,                type: Boolean
  
  # === VALIDATIONS === #

  validates :status, 
    inclusion: { 
      in: STATUS_VALUES, 
      message: "%{value} is not a valid status" 
    }
  validates :review_status, 
    inclusion: {
      in: REVIEW_STATUS_VALUES,
      message: "%{value} is not a valid review status"
    }
  validates :type,
    inclusion: {
      in: TYPE_VALUES,
      message: "%{value} is not a valid type"
    }

  validates :name,
    presence: true,
    length: { within: 2..MAX_NAME_LENGTH }
  validates :slug, 
    presence: true, 
    length: { within: 2..MAX_SLUG_LENGTH },
    uniqueness: { message: "'%{value}' is already taken." }, 
    format: { 
      with: /\A[a-z0-9-]+\Z/, 
      message: "must be dash case (only lowercase letters, numbers and dashes)"
    }

  # === CALLBACK === #

  before_save :enforce_field_limitations

  # === INSTANCE METHODS === #

  # None Yet

  # === PROTECTED METHODS === #

  protected

  def enforce_field_limitations
    # Slug: Replace multiple dashes with a single dash. Remove leading and trailing dashes.
    if slug_changed?
      self.slug = slug.gsub(/-{2,}/, '-').gsub(/\A-|-\Z/, '')
    end
  end

end