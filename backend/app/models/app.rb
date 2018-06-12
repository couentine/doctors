#==========================================================================================================================================#
# 
# APP MODEL
# 
# Do not manage apps directly from the model, use the following decorators:
# - Use AppChangeDecorator to create, modify and delete an app.
# - Use AppUserMembershipDecorator to manage member users.
# - Use AppGroupMembershipDecorator to manage member groups.
# 
#==========================================================================================================================================#

class App
  include Mongoid::Document
  include Mongoid::Timestamps
  include FieldHistory
  include AsyncCallbacks
  
  # === CONSTANTS === #

  STATUS_VALUES = ['pending', 'active', 'disabled']
  REVIEW_STATUS_VALUES = ['requested', 'approved', 'denied']
  JOINABILITY_VALUES = ['open', 'by_request', 'closed']
  MAX_NAME_LENGTH = 50
  MAX_SLUG_LENGTH = 30
  MAX_SUMMARY_LENGTH = 140
  MAX_DESCRIPTION_LENGTH = 3000
  MAX_ORGANIZATION_LENGTH = 300
  MAX_WEBSITE_LENGTH = 200
  MAX_EMAIL_LENGTH = 100

  # === RELATIONSHIPS === #

  belongs_to :creator,                    inverse_of: :created_apps,          class_name: 'User'
  belongs_to :owner,                      inverse_of: :owned_apps,            class_name: 'User'
  has_one :proxy_user,                    inverse_of: :proxy_app,             class_name: 'User',   dependent: :destroy
  
  has_many :user_memberships,             class_name: 'AppUserMembership',    dependent: :destroy
  has_and_belongs_to_many :users,         inverse_of: :apps,                  class_name: 'User'
  has_and_belongs_to_many :pending_users, inverse_of: :pending_apps,          class_name: 'User'
  has_and_belongs_to_many :member_users,  inverse_of: :member_of_apps,        class_name: 'User'
  has_and_belongs_to_many :admin_users,   inverse_of: :admin_of_apps,         class_name: 'User'
  has_and_belongs_to_many :disabled_users,inverse_of: :disabled_apps,         class_name: 'User'
 
  has_many :group_memberships,            class_name: 'AppGroupMembership',   dependent: :destroy
  has_and_belongs_to_many :groups,        inverse_of: :apps,                  class_name: 'Group'
  has_and_belongs_to_many :pending_groups,inverse_of: :pending_apps,          class_name: 'Group'
  has_and_belongs_to_many :disabled_groups,inverse_of: :disabled_apps,        class_name: 'Group'

  # === EDITABLE FIELDS === #

  field :review_status,                   type: String, default: 'requested', metadata: { history_of: :values }
  field :name,                            type: String,                       metadata: { history_of: :values }
  field :slug,                            type: String,                       metadata: { history_of: :values }
  field :user_joinability,                type: String, default: 'open',      metadata: { history_of: :values }
  field :group_joinability,               type: String, default: 'open',      metadata: { history_of: :values }

  field :summary,                         type: String,                       metadata: { history_of: :values }
  field :description,                     type: String,                       metadata: { history_of: :values }
  field :organization,                    type: String,                       metadata: { history_of: :values }
  field :website,                         type: String,                       metadata: { history_of: :values }
  field :email,                           type: String,                       metadata: { history_of: :values }
  
  field :new_image_url,                   type: String,                       metadata: { history_of: :times }

  # === CALCULATED FIELDS === #

  field :status,                          type: String, default: 'pending'

  field :pending,                         type: Boolean, default: true
  field :active,                          type: Boolean, default: false
  field :disabled,                        type: Boolean, default: false

  field :user_count,                      type: Integer, default: 0
  field :group_count,                     type: Integer, default: 0

  mount_uploader :image,                  S3BadgeUploader
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
  validates :user_joinability,
    inclusion: {
      in: JOINABILITY_VALUES,
      message: "%{value} is not a valid joinability value"
    }
  validates :group_joinability,
    inclusion: {
      in: JOINABILITY_VALUES,
      message: "%{value} is not a valid joinability value"
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
  validates :summary,                     length: { maximum: MAX_SUMMARY_LENGTH }
  validates :description,                 length: { maximum: MAX_DESCRIPTION_LENGTH }
  validates :organization,                length: { maximum: MAX_ORGANIZATION_LENGTH }
  validates :website,                     length: { maximum: MAX_WEBSITE_LENGTH }
  validates :email,                       length: { maximum: MAX_EMAIL_LENGTH }

  # === CALLBACKS === #

  before_validation :update_calculated_fields
  before_save :enforce_field_limitations

  # === ASYNC CALLBACKS === #

  ASYNC_CALLBACKS = [
    :process_image
  ]

  # === INSTANCE METHODS === #

  def standard?
    return STANDARD_APPS.include? slug
  end

  def mandatory?
    return MANDATORY_APPS.include? slug
  end

  alias_method :required, 'mandatory?'

  def full_url
    "#{ENV['root_url'] || 'https://www.badgelist.com'}/apps/#{slug}"
  end

  # === CLASS METHODS === #

  # This will find by id or slug
  def self.find(input)
    app = nil

    if input.to_s.match /^[0-9a-fA-F]{24}$/
      app = super rescue nil
    end

    if app.nil?
      app = App.where(slug: input.to_s.downcase).first

      # If this is a standard app which hasn't been created then we create it right now
      # NOTE: This is a weird place to put this works for now and prevents any failure of finding the standard apps.
      if app.nil? && STANDARD_APPS.include?(input.to_s.downcase)
        StandardAppInitService.new.perform
        app = App.where(slug: input.to_s.downcase).first # this should now return the app
      end
    end

    app
  end

  protected

  # === SYNCHRONOUS CALLBACK METHODS === #

  def update_calculated_fields
    if !destroyed?
      self.new_image_url = APP_CONFIG['default_app_image_url'] if new_image_url.blank?
      self.processing_image = new_record? || new_image_url_changed?

      if review_status == 'denied'
        self.status = 'disabled'
      elsif review_status == 'approved'
        self.status = 'active'
      else
        self.status = 'pending'
      end

      self.pending = status == 'pending'
      self.active = status == 'active'
      self.disabled = status == 'disabled'

      self.user_count = user_ids.count
      self.group_count = group_ids.count
    end

    true
  end

  def enforce_field_limitations
    # Slug: Replace multiple dashes with a single dash. Remove leading and trailing dashes.
    if slug_changed?
      self.slug = slug.gsub(/-{2,}/, '-').gsub(/\A-|-\Z/, '')
    end
  end

  # === ASYNC CALLBACK METHODS === #

  def process_image?
    processing_image
  end

  # Processes changes to the image from carrierwave direct key
  def process_image!
    self.processing_image = false
    self.remote_image_url = new_image_url
    self.save!
  end  

end