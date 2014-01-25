class Tag
  include Mongoid::Document
  include Mongoid::Timestamps
  include StringTools

  # === CONSTANTS === #
  
  MAX_NAME_LENGTH = 50

  # === RELATIONSHIPS === #

  belongs_to :badge

  # === FIELDS & VALIDATIONS === #
  
  field :name,                type: String
  field :name_with_caps,      type: String

  field :wiki,                type: String
  field :wiki_versions,       type: Array
  field :wiki_sections,       type: Array
  field :tags,                type: Array
  field :tags_with_caps,      type: Array

  field :current_user,        type: String # used when logging wiki_versions
  field :current_username,    type: String # used when logging wiki_versions
  field :flags,               type: Array

  validates :name, presence: true, length: { within: 2..MAX_NAME_LENGTH }, 
            uniqueness: { scope: :badge }, exclusion: { in: APP_CONFIG['blocked_url_slugs'],
            message: "%{value} is a specially reserved url." }            
  validates :badge, presence: true

  # Which fields are accessible?
  attr_accessible :name_with_caps, :wiki

  # === CALLBACKS === #

  before_validation :set_default_values, on: :create
  before_validation :update_caps_field
  after_validation :update_wiki_sections
  after_validation :update_wiki_versions # DO store the first value since it comes from the user

  # === TAG METHODS === #

  def to_param
    name
  end

protected

  def set_default_values
    self.flags ||= []
  end

  def update_caps_field
    if name_with_caps.nil?
      self.name = nil
    else
      self.name = name_with_caps.downcase
    end
  end

  def update_wiki_sections
    if wiki_changed?
      linkified_result = linkify_text(wiki, badge.group, badge)
      self.wiki_sections = linkified_result[:text].split(SECTION_DIVIDER_REGEX)
      self.tags = linkified_result[:tags]
      self.tags_with_caps = linkified_result[:tags_with_caps]
    end
  end

  def update_wiki_versions
    if wiki_changed?
      current_version_row = { :wiki => wiki, :user => current_user, 
                              :username => current_username, :updated_at => Time.now,
                              :updated_at_text => Time.now.strftime("%-m/%-d/%y at %l:%M%P") }

      if wiki_versions.nil? || (wiki_versions.length == 0)
        self.wiki_versions = [current_version_row]
      elsif wiki_versions.last[:wiki] != wiki
        self.wiki_versions << current_version_row
      end
    end
  end

end
