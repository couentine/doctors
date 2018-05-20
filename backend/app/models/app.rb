#==========================================================================================================================================#
# 
# APP MODEL
# 
# Use the services in `/services/app` to create and modify apps rather than editing them directly.
# 
#==========================================================================================================================================#

class App
  include Mongoid::Document
  include Mongoid::Timestamps
  
  # === CONSTANTS === #

  STATUS_VALUES = ['active', 'inactive']
  REVIEW_STATUS_VALUES = ['pending', 'approved', 'disabled']
  TYPE_VALUES = ['free', 'paid', 'private']

  # === RELATIONSHIPS === #

  belongs_to :owner,                      inverse_of: :owned_apps,  class_name: 'User'
  has_one :proxy_user,                    inverse_of: :proxy_app,   class_name: 'User'
  
  has_many :user_memberships,             class_name: 'AppUserMembership',  dependent: :delete_all

  # === FIELDS === #

  field :status,                          type: String, default: 'active'
  field :review_status,                   type: String, default: 'approved'
  field :name,                            type: String
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

  validates :status, inclusion: { in: STATUS_VALUES, message: "%{value} is not a valid status" }
  validates :review_status, inclusion: { in: REVIEW_STATUS_VALUES, message: "%{value} is not a valid review status" }
  validates :type, inclusion: { in: TYPE_VALUES, message: "%{value} is not a valid type" }

  # === CALLBACK === #

  # None Yet

  # === INSTANCE METHODS === #

  # None Yet

  # === PROTECTED METHODS === #

  protected

  # None Yet

end