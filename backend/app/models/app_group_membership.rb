#==========================================================================================================================================#
# 
# APP GROUP MEMBERSHIP MODEL
# 
# Use AppGroupMembershipDecorator to manage members.
# 
#==========================================================================================================================================#

class AppGroupMembership
  include Mongoid::Document
  include Mongoid::Timestamps
  include FieldHistory
  
  # === CONSTANTS === #

  STATUS_VALUES = ['pending', 'active', 'disabled']
  APPROVAL_STATUS_VALUES = ['requested', 'approved', 'denied']
  USER_ACCESS_VALUES = ['members', 'all']

  # === RELATIONSHIPS === #

  belongs_to :app
  belongs_to :group,                      inverse_of: :app_memberships,                 class_name: 'Group'
  belongs_to :creator,                    inverse_of: :created_app_group_memberships,   class_name: 'Group'

  # === EDITABLE FIELDS === #

  field :app_approval_status,             type: String, default: 'requested',     metadata: { history_of: :values }
  field :group_approval_status,           type: String, default: 'requested',     metadata: { history_of: :values }

  field :app_user_access,                 type: String, default: 'members',       metadata: { history_of: :values }
  field :group_user_access,               type: String, default: 'members',       metadata: { history_of: :values }

  # === CALCULATED FIELDS === #
  
  field :status,                          type: String, default: 'pending'

  field :pending,                         type: Boolean, default: true
  field :active,                          type: Boolean, default: false
  field :disabled,                        type: Boolean, default: false
  
  # === VALIDATIONS === #

  validates :status, inclusion: { in: STATUS_VALUES, message: "%{value} is not a valid membership status" }
  validates :app_approval_status, inclusion: { in: APPROVAL_STATUS_VALUES, message: "%{value} is not a valid approval status" }
  validates :group_approval_status, inclusion: { in: APPROVAL_STATUS_VALUES, message: "%{value} is not a valid approval status" }
  validates :app_user_access, inclusion: { in: USER_ACCESS_VALUES, message: "%{value} is not a valid user access level" }
  validates :group_user_access, inclusion: { in: USER_ACCESS_VALUES, message: "%{value} is not a valid user access level" }

  # === CALLBACKS === #

  after_validation :update_calculated_fields
  before_save :enforce_field_limitations

  # === PROTECTED METHODS === #

  protected

  def update_calculated_fields
    if (app_approval_status == 'denied') || (group_approval_status == 'denied')
      self.status = 'disabled'
    elsif (app_approval_status == 'approved') && (group_approval_status == 'approved')
      self.status = 'active'
    else
      self.status = 'pending'
    end

    self.pending = status == 'pending'
    self.active = status == 'active'
    self.disabled = status == 'disabled'
  end

  def enforce_field_limitations
    # Group user access cannot be wider than the access enabled by the app
    if (app_user_access == 'members') && (group_user_access == 'all')
      self.group_user_access = 'members'
    end
  end

end