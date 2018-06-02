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

  # === RELATIONSHIPS === #

  belongs_to :app
  belongs_to :group,                      inverse_of: :app_memberships,                 class_name: 'Group'
  belongs_to :creator,                    inverse_of: :created_app_group_memberships,   class_name: 'Group'

  # === EDITABLE FIELDS === #

  field :app_approval_status,             type: String, default: 'requested',     metadata: { history_of: :values }
  field :group_approval_status,           type: String, default: 'requested',     metadata: { history_of: :values }

  # === CALCULATED FIELDS === #
  
  field :status,                          type: String, default: 'pending'

  field :pending,                         type: Boolean, default: true
  field :active,                          type: Boolean, default: false
  field :disabled,                        type: Boolean, default: false
  
  # === VALIDATIONS === #

  validates :app,
    presence: true
  validates :group,
    presence: true,
    uniqueness: {
      scope: :app,
      message: "group with id '%{value}' already has a membership for this app"
    }

  validates :status,
    inclusion: {
      in: STATUS_VALUES,
      message: "%{value} is not a valid membership status"
    }
  validates :app_approval_status,
    inclusion: {
      in: APPROVAL_STATUS_VALUES,
      message: "%{value} is not a valid approval status"
    }
  validates :group_approval_status,
    inclusion: {
      in: APPROVAL_STATUS_VALUES,
      message: "%{value} is not a valid approval status"
    }

  # === CALLBACKS === #

  validate :no_reparenting
  before_validation :update_calculated_fields

  # === INSTANCE METHODS === #

  def full_url
    "#{ENV['root_url'] || 'https://www.badgelist.com'}/apps/#{app.slug}/group_memberships/#{id.to_s}"
  end

  # === PROTECTED METHODS === #

  protected

  def no_reparenting
    if persisted? 
      errors.add(:app_id, 'cannot be changed after the membership is created') if app_id_changed? && app_id.present?
      errors.add(:group_id, 'cannot be changed after the membership is created') if group_id_changed? && group_id.present?
    end
  end

  def update_calculated_fields
    if !destroyed?
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

    true
  end

end