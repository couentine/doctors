class Badge
  include Mongoid::Document
  include Mongoid::Timestamps
  include StringTools

  # === CONSTANTS === #
  
  MAX_NAME_LENGTH = 50
  MAX_URL_LENGTH = 40
  MAX_SUMMARY_LENGTH = 140
  SECTION_DIVIDER_REGEX = /-+\s*<br *\/?>\s*/i

  # === RELATIONSHIPS === #

  belongs_to :group
  belongs_to :creator, inverse_of: :created_badges, class_name: "User"

  # === FIELDS & VALIDATIONS === #

  field :name,                type: String
  field :url,                 type: String
  field :image_url,           type: String
  field :summary,             type: String
  field :info,                type: String
  field :info_sections,       type: Array
  field :info_versions,       type: Array
  field :current_user,        type: String # used when logging info_versions
  field :current_user_name,   type: String # used when logging info_versions

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
  
  # === CALLBACKS === #

  after_validation :set_default_values, on: :create
  after_validation :update_info_sections
  after_validation :update_info_versions, on: :update # Don't store the first (default) value

  # === BADGE METHODS === #

  def to_param
    url
  end

protected
  
  def set_default_values
    self.info ||= APP_CONFIG['default_badge_info']
  end

  def update_info_sections
    if info_changed?
      self.info_sections = linkify_text(info, group, self).split(SECTION_DIVIDER_REGEX)
    end
  end

  def update_info_versions
    if info_changed?
      current_version_row = { :info => info, :user => current_user, 
                              :user_name => current_user_name, :updated_at => Time.now,
                              :updated_at_text => Time.now.strftime("%-m/%-d/%y at %l:%M%P") }

      if info_versions.nil? || (info_versions.length == 0)
        self.info_versions = [current_version_row]
      elsif info_versions.last[:info] != info
        self.info_versions << current_version_row
      end
    end
  end

end