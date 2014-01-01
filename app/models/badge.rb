class Badge
  include Mongoid::Document
  include Mongoid::Timestamps
  include StringTools

  # === CONSTANTS === #
  
  MAX_NAME_LENGTH = 50
  MAX_URL_LENGTH = 20
  MAX_SUMMARY_LENGTH = 140
  RECENT_DATE_THRESHOLD = 10.days # Used to filter "recent" activity & changes

  # === RELATIONSHIPS === #

  belongs_to :group
  belongs_to :creator, inverse_of: :created_badges, class_name: "User"
  has_many :logs, dependent: :nullify

  # === FIELDS & VALIDATIONS === #

  field :name,                type: String
  field :url,                 type: String
  field :image_url,           type: String
  field :summary,             type: String
  field :info,                type: String
  field :info_sections,       type: Array
  field :info_versions,       type: Array
  field :current_user,        type: String # used when logging info_versions
  field :current_username,   type: String # used when logging info_versions

  validates :name, presence: true, length: { maximum: MAX_NAME_LENGTH }
  validates :url, presence: true, length: { within: 3..MAX_URL_LENGTH },
            uniqueness: { scope: :group },
            format: { with: /\A[\w-]+\Z/, message: "only allows url-friendly characters" },
            exclusion: { in: APP_CONFIG['blocked_url_slugs'],
                         message: "%{value} is a specially reserved url." }
  validates :image_url, presence: true
  validates :summary, length: { maximum: MAX_SUMMARY_LENGTH }
  validates :group, presence: true
  validates :creator, presence: true

  # Which fields are accessible?
  attr_accessible :group, :name, :url, :image_url, :summary, :info, :current_user, :current_username
  
  # === CALLBACKS === #

  before_validation :set_default_values, on: :create
  after_create :add_creator_as_expert
  after_validation :update_info_sections
  after_validation :update_info_versions, on: :update # Don't store the first (default) value

  # === BADGE METHODS === #

  def to_param
    url
  end

  # Returns all non-validated logs, sorted by user's name
  def learner_logs
    logs.find_all do |log|
      (log.validation_status != 'validated') \
      && !log.detached_log
    end.sort_by do |log|
      log.user.name
    end
  end

  # Returns all validated logs, sorted by user's name
  def expert_logs
    logs.find_all do |log|
      (log.validation_status == 'validated') \
      && !log.detached_log
    end.sort_by do |log|
      log.user.name
    end
  end

  # Returns all learners who are currently requesting validation
  # or who have recently withdrawn their validation requests.
  # Reverse sorts logs by request/withdrawal date
  def requesting_learner_logs
    logs.find_all do |log|
      !log.detached_log && ( \
        (log.validation_status == 'requested') \
        || ((log.validation_status == 'withdrawn') \
            && (log.date_withdrawn > (Time.now - RECENT_DATE_THRESHOLD))) \
      )
    end.sort_by do |log|
      log.date_withdrawn || log.date_requested
    end
  end

  # Returns all recently validated experts, reverse sorted by issue date
  def new_expert_logs
    logs.find_all do |log|
      !log.detached_log \
      && (log.validation_status == 'validated') \
      && (log.date_issued > (Time.now - RECENT_DATE_THRESHOLD))
    end.sort_by do |log|
      log.date_withdrawn || log.date_requested
    end
  end

  # Adds a learner to the badge by creating or reattaching a log for them
  # NOTE: If there is already a detached log this function will reattach it
  # Return value = the newly created/reattached log
  def add_learner(user)
    the_log = Badge.logs.find_by(user: user) rescue nil

    if the_log
      if the_log.detached_log
        the_log.detached_log = false
        the_log.save
      end
    else
      the_log = Log.new(badge: self, user: user)
      the_log.save
    end

    the_log
  end

protected
  
  def set_default_values
    self.info ||= APP_CONFIG['default_badge_info']
  end

  def add_creator_as_expert
    log = Log.create(badge: self, user: creator)
    time_string = Time.now.to_s(:full_date_time)
    log.add_validation(creator, "Badge Creator",
      "#{creator.name} created the badge on #{time_string}" \
      + " and was automatically added as an expert.")
  end

  def update_info_sections
    if info_changed?
      self.info_sections = linkify_text(info, group, self).split(SECTION_DIVIDER_REGEX)
    end
  end

  def update_info_versions
    if info_changed?
      current_version_row = { :info => info, :user => current_user, 
                              :username => current_username, :updated_at => Time.now,
                              :updated_at_text => Time.now.strftime("%-m/%-d/%y at %l:%M%P") }

      if info_versions.nil? || (info_versions.length == 0)
        self.info_versions = [current_version_row]
      elsif info_versions.last[:info] != info
        self.info_versions << current_version_row
      end
    end
  end

end