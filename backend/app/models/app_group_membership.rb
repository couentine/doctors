#==========================================================================================================================================#
# 
# APP GROUP MEMBERSHIP MODEL
# 
# FIXME >> Add notes on how to update.
# 
#==========================================================================================================================================#

class AppGroupMembership
  include Mongoid::Document
  include Mongoid::Timestamps
  
  # === CONSTANTS === #

  APPROVAL_STATUS_VALUES = ['requested', 'approved', 'denied']
  USER_ACCESS_VALUES = ['members', 'all']

  # === RELATIONSHIPS === #

  belongs_to :app
  belongs_to :group

  # === FIELDS === #

  field :app_approval_status,             type: String, default: 'requested'
  field :group_approval_status,           type: String, default: 'requested'

  field :app_user_access,                 type: String, default: 'members'
  field :group_user_access,               type: String, default: 'members'
  
  # === VALIDATIONS === #

  validates :app_approval_status, inclusion: { in: APPROVAL_STATUS_VALUES, message: "%{value} is not a valid approval status" }
  validates :group_approval_status, inclusion: { in: APPROVAL_STATUS_VALUES, message: "%{value} is not a valid approval status" }
  validates :app_user_access, inclusion: { in: USER_ACCESS_VALUES, message: "%{value} is not a valid user access level" }
  validates :group_user_access, inclusion: { in: USER_ACCESS_VALUES, message: "%{value} is not a valid user access level" }

  # === CALLBACK === #

  before_save :enforce_field_limitations

  # === INSTANCE METHODS === #

  # None Yet

  # === PROTECTED METHODS === #

  protected

  def enforce_field_limitations
    # Group user access cannot be wider than the access enabled by the app
    if (app_user_access == 'members') && (group_user_access == 'all')
      self.group_user_access = 'members'
    end
  end

end