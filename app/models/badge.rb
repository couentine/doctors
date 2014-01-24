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
  field :tags,                type: Array
  field :tags_with_caps,      type: Array
  
  field :current_user,        type: String # used when logging info_versions
  field :current_username,    type: String # used when logging info_versions
  field :flags,               type: Array

  validates :name, presence: true, length: { maximum: MAX_NAME_LENGTH }
  validates :url, presence: true, length: { within: 2..MAX_URL_LENGTH },
            uniqueness: { scope: :group },
            format: { with: /\A[\w-]+\Z/, message: "only allows url-friendly characters" },
            exclusion: { in: APP_CONFIG['blocked_url_slugs'],
                         message: "%{value} is a specially reserved url." }
  validates :image_url, presence: true
  validates :summary, length: { maximum: MAX_SUMMARY_LENGTH }
  validates :group, presence: true
  validates :creator, presence: true

  # Which fields are accessible?
  attr_accessible :name, :url, :image_url, :summary, :info
  
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
    end.reverse
  end

  # Returns all recently validated experts, reverse sorted by issue date
  def new_expert_logs
    logs.find_all do |log|
      !log.detached_log \
      && (log.validation_status == 'validated') \
      && !log.date_issued.nil? \
      && (log.date_issued > (Time.now - RECENT_DATE_THRESHOLD))
    end.sort_by do |log|
      log.date_issued
    end.reverse
  end

  # Adds a learner to the badge by creating or reattaching a log for them
  # NOTE: If there is already a detached log this function will reattach it
  # date_started: Defaults to nil. If set, overrides the log.date_started fields
  # Return value = the newly created/reattached log
  def add_learner(user, date_started = nil)
    the_log = Badge.logs.find_by(user: user) rescue nil

    if the_log
      if the_log.detached_log
        the_log.detached_log = false
        the_log.save
      end
    else
      the_log = Log.new(date_started: date_started)
      the_log.badge = self
      the_log.user = user
      the_log.save
    end

    the_log
  end

  # Returns all entries (posts AND validations), sorted from newest to oldest
  # NOTE: Uses pagination
  def entries(page = 1, page_size = APP_CONFIG['page_size_normal'])
    log_ids = logs.map{ |log| log.id }
    Entry.where(:log.in => log_ids).order_by(:updated_at.desc).page(page).per(page_size)
  end

  # Returns the ACTUAL validation threshold based on the group settings AND the badge expert count
  def current_validation_threshold
    validation_threshold = expert_logs.count

    if group && group.validation_threshold
      validation_threshold = [validation_threshold, group.validation_threshold].min
    end

    validation_threshold
  end

protected
  
  def set_default_values
    self.info ||= APP_CONFIG['default_badge_info']
    self.flags ||= []
  end

  def add_creator_as_expert
    log = Log.new
    log.badge = self
    log.user = creator
    log.save! 
    # NOTE: This log will automatically be validated (by log.update_stati) 
    # and self-validated (by log.back_validate_if_needed)
  end

  def update_info_sections
    if info_changed?
      linkified_result = linkify_text(info, group, self)
      self.info_sections = linkified_result[:text].split(SECTION_DIVIDER_REGEX)
      self.tags = linkified_result[:tags]
      self.tags_with_caps = linkified_result[:tags_with_caps]
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