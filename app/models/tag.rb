class Tag
  include Mongoid::Document
  include Mongoid::Timestamps
  include JSONFilter
  include StringTools

  # === CONSTANTS === #
  
  MAX_NAME_LENGTH = 50
  MAX_SUMMARY_LENGTH = 300
  TYPE_VALUES = ['requirement', 'wiki']
  EDITABILITY_VALUES = ['learners', 'experts', 'admins']
  PRIVACY_VALUES = ['public', 'private', 'secret']
  JSON_FIELDS = [:badge, :name, :name_with_caps, :display_name, :editability, :privacy, 
    :wiki_sections, :tags, :tags_with_caps]

  # === RELATIONSHIPS === #

  belongs_to :badge
  has_many :entries, dependent: :nullify

  # === FIELDS & VALIDATIONS === #
  
  field :name,                type: String
  field :name_with_caps,      type: String
  field :display_name,        type: String
  field :type,                type: String, default: 'wiki'
  field :sort_order,          type: Integer

  field :editability,         type: String, default: 'learners'
  field :privacy,             type: String, default: 'public'
  field :summary,             type: String
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
  validates :type, inclusion: { in: TYPE_VALUES, message: "%{value} is not a valid type" }
  validates :summary, length: { maximum: MAX_SUMMARY_LENGTH }
  validates :editability, inclusion: { in: EDITABILITY_VALUES, 
    message: "%{value} is not a valid type of editability" }
  validates :privacy, inclusion: { in: PRIVACY_VALUES, 
    message: "%{value} is not a valid type of privacy" }

  # Which fields are accessible?
  attr_accessible :display_name, :type, :sort_order, :summary, :wiki, :editability, :privacy

  # === CALLBACKS === #

  before_validation :update_validated_fields
  after_validation :copy_name_field_errors
  after_validation :update_wiki_sections
  after_validation :update_wiki_versions # DO store the first value since it comes from the user
  after_save :update_child_entries

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

    # This should make it impossible to ever trigger the max summary length validation
    if summary && (summary.length > MAX_SUMMARY_LENGTH)
      self.summary = summary[0, MAX_SUMMARY_LENGTH]
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
    elsif wiki_sections.nil?
      self.wiki_sections = []
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

  # If the tag name changes we want to update the parent_tag field on all of the child entries.
  # The parent_tag field isn't really used right now so this is mostly just to maintain consistency.
  def update_child_entries
    if name_with_caps_changed? && !entries.empty?
      entries.each do |entry|
        entry.parent_tag = name_with_caps
        entry.timeless.save
      end
    end
  end

  # NOTE: DISABLING FOR NOW BECAUSE CAUSES INFINITE LOOP FROM badge.update_topics
  # When the display name changes for a requirement, this callback updates the badge
  def update_badge_topic_list_text
    if display_name_changed? && (type == 'requirement')
      badge.refresh_topic_list_text
      badge.timeless.save
    end
  end
end
