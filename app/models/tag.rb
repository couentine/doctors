class Tag
  include Mongoid::Document
  include Mongoid::Timestamps
  include JSONFilter
  include StringTools

  # === CONSTANTS === #
  
  MAX_NAME_LENGTH = 50
  EDITABILITY_VALUES = ['learners', 'experts', 'admins']
  JSON_FIELDS = [:badge, :name, :name_with_caps, :display_name, :editability, :wiki_sections,
    :tags, :tags_with_caps]

  # === RELATIONSHIPS === #

  belongs_to :badge

  # === FIELDS & VALIDATIONS === #
  
  field :name,                type: String
  field :name_with_caps,      type: String
  field :display_name,        type: String

  field :editability,         type: String, default: 'learners'
  field :wiki,                type: String
  field :wiki_versions,       type: Array
  field :wiki_sections,       type: Array
  field :tags,                type: Array
  field :tags_with_caps,      type: Array

  field :current_user,        type: String # used when logging wiki_versions
  field :current_username,    type: String # used when logging wiki_versions
  field :flags,               type: Array, default: []

  validates :badge, presence: true
  validates :name, presence: true, length: { within: 2..MAX_NAME_LENGTH }, 
    uniqueness: { scope: :badge }, exclusion: { in: APP_CONFIG['blocked_url_slugs'],
    message: "%{value} is a specially reserved url." }
  validates :display_name, presence: true
  validates :editability, inclusion: { in: EDITABILITY_VALUES, 
    message: "%{value} is not a valid type of editability" }

  # Which fields are accessible?
  attr_accessible :display_name, :wiki, :editability

  # === CALLBACKS === #

  before_validation :update_validated_fields
  after_validation :copy_name_field_errors
  after_validation :update_wiki_sections
  after_validation :update_wiki_versions # DO store the first value since it comes from the user
  after_save :update_badge_display_name

  # === TAG METHODS === #

  def to_param
    name_with_caps
  end

protected

  def update_validated_fields
    if display_name.nil?
      self.name = nil
      self.name_with_caps = nil
    else
      self.name_with_caps = tagify_string display_name
      self.name = name_with_caps.downcase
    end
  end

  # Takes any errors from name to display_name
  def copy_name_field_errors
    self.errors[:display_name] = self.errors[:name] if self.errors[:display_name].blank?
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

  # When the display name changes, this callback goes up to the badge and if the tag exists
  # in the badge topic list it will change it there as well
  def update_badge_display_name
    if display_name_changed? && !badge.topics.empty?
      topic_item = badge.topics.detect { |t| t['tag_name'] == name }
      if topic_item && (topic_item['tag_display_name'] != display_name)
        topic_item['tag_display_name'] = display_name
        badge.save
      end
    end
  end
end
