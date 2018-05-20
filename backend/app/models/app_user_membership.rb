#==========================================================================================================================================#
# 
# APP USER MEMBERSHIP MODEL
# 
# Use the services in `/services/app` to create and modify app memberships.
# 
#==========================================================================================================================================#

class AppUserMembership
  include Mongoid::Document
  include Mongoid::Timestamps
  
  # === CONSTANTS === #

  TYPE_VALUES = ['member', 'admin']
  APPROVAL_STATUS_VALUES = ['requested', 'approved', 'denied']

  # === RELATIONSHIPS === #

  belongs_to :app
  belongs_to :user

  # === FIELDS === #

  field :type,                            type: String, default: 'member'

  field :app_approval_status,             type: String, default: 'requested'
  field :user_approval_status,            type: String, default: 'requested'
  
  # === VALIDATIONS === #

  validates :type, inclusion: { in: TYPE_VALUES, message: "%{value} is not a valid membership type" }
  validates :app_approval_status, inclusion: { in: APPROVAL_STATUS_VALUES, message: "%{value} is not a valid approval status" }
  validates :user_approval_status, inclusion: { in: APPROVAL_STATUS_VALUES, message: "%{value} is not a valid approval status" }

  # === CALLBACK === #

  # None Yet

  # === INSTANCE METHODS === #

  # None Yet

  # === PROTECTED METHODS === #

  protected

  # None Yet

end