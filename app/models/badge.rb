class Badge
  include Mongoid::Document
  include Mongoid::Timestamps
  include StringTools

  # === CONSTANTS === #
  
  MAX_NAME_LENGTH = 50
  MAX_URL_LENGTH = 40
  MAX_SUMMARY_LENGTH = 140
  SECTION_DIVIDER_REGEX = /<p>\s*-+\s*<\/p>/

  # === RELATIONSHIPS === #

  belongs_to :group
  belongs_to :creator, inverse_of: :created_badges, class_name: "User"

  # === FIELDS & VALIDATIONS === #

  field :name,          type: String
  field :url,     type: String
  field :image_url,     type: String
  field :summary,       type: String
  field :info,   type: String

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
  
  # === BADGE METHODS === #

  def to_param
    url
  end

  # returns linkified info text broken into sections based on empty paragraphs
  def info_sections
    linkify_text(info, group, self).split(SECTION_DIVIDER_REGEX)
  end

end