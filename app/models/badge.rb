class Badge
  include Mongoid::Document
  include Mongoid::Timestamps

  # === CONSTANTS === #
  
  MAX_NAME_LENGTH = 50
  MAX_URL_LENGTH = 40
  MAX_SUMMARY_LENGTH = 140

  # === RELATIONSHIPS === #

  belongs_to :group
  belongs_to :creator, inverse_of: :created_badges, class_name: "User"

  # === FIELDS & VALIDATIONS === #

  field :name,          type: String
  field :url,     type: String
  field :image_url,     type: String
  field :summary,       type: String
  field :description,   type: String

  validates :name, presence: true, length: { maximum: MAX_NAME_LENGTH }
  validates :url, presence: true, length: { within: 3..MAX_URL_LENGTH },
            uniqueness: { scope: :group },
            format: { with: /\A[\w-]+\Z/, message: "only allows url-friendly characters" },
            exclusion: { in: APP_CONFIG['blocked_url_slugs'],
                         message: "%{value} is a specially reserved url." }
  validates :image_url, presence: true
  validates :summary, presence: true, length: { maximum: MAX_SUMMARY_LENGTH }
  validates :group, presence: true
  validates :creator, presence: true
  
  # === BADGE METHODS === #

  def to_param
    url
  end

end