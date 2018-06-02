#==========================================================================================================================================#
# 
# APP USER MEMBERSHIP MODEL
# 
# Use AppUserMembershipDecorator to manage members.
# 
#==========================================================================================================================================#

class AppUserMembership
  include Mongoid::Document
  include Mongoid::Timestamps
  include FieldHistory
  
  # === CONSTANTS === #

  TYPE_VALUES = ['member', 'admin']
  STATUS_VALUES = ['pending', 'active', 'disabled']
  APPROVAL_STATUS_VALUES = ['requested', 'approved', 'denied']

  # === RELATIONSHIPS === #

  belongs_to :app
  belongs_to :user,                       inverse_of: :app_memberships,               class_name: 'User'
  belongs_to :creator,                    inverse_of: :created_app_user_memberships,  class_name: 'User'

  # === EDITABLE FIELDS === #

  field :type,                            type: String, default: 'member',        metadata: { history_of: :values }

  field :app_approval_status,             type: String, default: 'requested',     metadata: { history_of: :values }
  field :user_approval_status,            type: String, default: 'approved',      metadata: { history_of: :values }
  
  # === CALCULATED FIELDS === #
  
  field :status,                          type: String, default: 'active'

  field :pending,                         type: Boolean, default: true
  field :active,                          type: Boolean, default: false
  field :disabled,                        type: Boolean, default: false
  
  # === VALIDATIONS === #

  validates :app,
    presence: true
  validates :user,
    presence: true,
    uniqueness: {
      scope: :app,
      message: "user with id '%{value}' already has a membership for this app"
    }

  validates :type,
    inclusion: {
      in: TYPE_VALUES,
      message: "%{value} is not a valid membership type"
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
  validates :user_approval_status,
    inclusion: {
      in: APPROVAL_STATUS_VALUES,
      message: "%{value} is not a valid approval status"
    }

  # === CALLBACKS === #

  validate :no_reparenting
  before_validation :update_calculated_fields

  # === INSTANCE METHODS === #

  def member?
    return active? && (type == 'member')
  end
  
  def admin?
    return active? && (type == 'admin')
  end

  def full_url
    "#{ENV['root_url'] || 'https://www.badgelist.com'}/apps/#{app.slug}/user_memberships/#{id.to_s}"
  end

  # === PROTECTED METHODS === #

  protected

  def no_reparenting
    if persisted? 
      errors.add(:app_id, 'cannot be changed after the membership is created') if app_id_changed? && app_id.present?
      errors.add(:user_id, 'cannot be changed after the membership is created') if user_id_changed? && user_id.present?
    end
  end

  def update_calculated_fields
    if !destroyed?
      if (app_approval_status == 'denied') || (user_approval_status == 'denied')
        self.status = 'disabled'
      elsif (app_approval_status == 'approved') && (user_approval_status == 'approved')
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