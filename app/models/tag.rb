class Tag
  include Mongoid::Document
  include Mongoid::Timestamps
  include JSONFilter
  include StringTools

  # === CONSTANTS === #
  
  MAX_NAME_LENGTH = 50
  MAX_SUMMARY_LENGTH = 300
  TYPE_VALUES = ['requirement', 'wiki']
  FORMAT_VALUES = ['text', 'link', 'image', 'tweet', 'code']
  EDITABILITY_VALUES = ['learners', 'experts', 'admins']
  PRIVACY_VALUES = ['public', 'private', 'secret']
  JSON_FIELDS = [:badge, :name, :name_with_caps, :display_name, :type, :format, :summary, 
    :wiki, :sort_order, :editability, :privacy, :tags, :tags_with_caps, :created_at,
    :updated_at]
  CLONE_FIELDS = [:_id, :name, :name_with_caps, :display_name, :type, :format, :summary, :wiki, 
    :sort_order, :editability, :privacy, :created_at, :updated_at]

  # === INSTANCE VARIABLES === #

  attr_accessor :context # Used to prevent certain callbacks from firing in certain contexts

  # === RELATIONSHIPS === #

  belongs_to :badge
  has_many :entries, dependent: :nullify

  # === FIELDS & VALIDATIONS === #
  
  field :name,                type: String
  field :name_with_caps,      type: String
  field :display_name,        type: String
  field :type,                type: String, default: 'wiki'
  field :format,              type: String, default: 'text'
  field :sort_order,          type: Integer

  field :editability,         type: String, default: 'experts'
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

  field :json_clone,          type: Hash, default: {}

  validates :badge, presence: true
  validates :name, presence: true, length: { within: 2..MAX_NAME_LENGTH }, 
    uniqueness: { scope: :badge }, exclusion: { in: APP_CONFIG['blocked_url_slugs'],
    message: "%{value} is a specially reserved url." }
  validates :display_name, presence: true
  validates :type, inclusion: { in: TYPE_VALUES, message: "%{value} is not a valid type" }
  validates :format, inclusion: { in: FORMAT_VALUES, message: "%{value} is not a valid format" }
  validates :summary, length: { maximum: MAX_SUMMARY_LENGTH }
  validates :editability, inclusion: { in: EDITABILITY_VALUES, 
    message: "%{value} is not a valid type of editability" }
  validates :privacy, inclusion: { in: PRIVACY_VALUES, 
    message: "%{value} is not a valid type of privacy" }

  # Which fields are accessible?
  attr_accessible :display_name, :type, :format, :sort_order, :summary, :wiki, :editability, 
    :privacy

  # === CALLBACKS === #

  before_validation :update_validated_fields
  after_validation :copy_name_field_errors
  after_validation :update_wiki_sections
  after_validation :update_wiki_versions # DO store the first value since it comes from the user
  before_save :update_json_clone_if_needed
  before_destroy :remove_from_badge
  after_save :update_child_entries

  # === TAG METHODS === #

  # Returns the font awesome icon which represents the specified format
  def self.format_icon(format_string)
    case format_string
    when 'link'
      return 'fa-link'
    when 'tweet'
      return 'fa-twitter'
    when 'image'
      return 'fa-camera'
    when 'code'
      return 'fa-code'
    else
      return 'fa-pencil'
    end
  end

  # Returns list of valid privacy values for a group of the specified type
  def self.privacy_values(group_type)
    if group_type == 'private'
      return ['public', 'private', 'secret']
    else
      return ['public', 'secret']
    end
  end

  # Returns the font awesome icon which represents the specified privacy state
  # group_type should equal the type field from the group record
  def self.privacy_icon(group_type, privacy_string)
    case privacy_string
    when 'secret'
      return 'fa-lock'
    when 'private'
      return 'fa-users'
    else
      if group_type == 'private'
        return 'fa-link'
      else
        return 'fa-globe'
      end
    end
  end

  # Returns text describing who can see entries for the specified privacy state
  # group_type should equal the type field from the group record
  def self.privacy_text(group_type, privacy_string)
    case privacy_string
    when 'secret'
      return 'only visible to badge awarders'
    when 'private'
      return 'only visible to group members'
    else
      if group_type == 'private'
        return 'visible to group members and anyone with the link'
      else
        return 'visible to public'
      end
    end
  end

  # === TAG ASYNC METHODS === #

  # Updates (or deletes) this tag's entry in the badge json clone
  def self.update_badge_json_clone(badge_id, tag_json_clone, is_deleted = false)
    badge = Badge.find(badge_id)
    badge.update_json_clone_tag(tag_json_clone, is_deleted)
    badge.save
  end

  # === INSTANCE METHODS === #

  def to_param
    name_with_caps
  end

  # Returns the font awesome icon code for this tag's format (ex: "fa-camera")
  def format_icon
    return Tag.format_icon(format)
  end

  # Returns the font awesome icon which represents this tag's privacy state
  # group_type should equal the type field from the group record
  def privacy_icon(group_type)
    return Tag.privacy_icon(group_type, privacy)
  end

  # Returns text describing who can see entries for this tag
  # group_type should equal the type field from the group record
  def privacy_text(group_type)
    return Tag.privacy_text(group_type, privacy)
  end

  def update_json_clone
    self.json_clone = self.as_json(use_default_method: true, only: CLONE_FIELDS)
    self.json_clone['created_at'] ||= Time.now
    self.json_clone['updated_at'] ||= Time.now
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

    # Editability for requirements must always match the badge editability
    if (type == 'requirement') && badge_id
      self.editability = badge.editability.to_s
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

  def update_json_clone_if_needed
    # First find the intersection of the fields to watch and the fields that have changed
    clone_field_names = CLONE_FIELDS.map{ |field_symbol| field_symbol.to_s }
    changed_clone_field_names = changed & clone_field_names

    unless changed_clone_field_names.blank?
      self.update_json_clone

      # Update the badge unless we're being called from the context of a badge async update
      if context != 'badge_async'
        Tag.delay(retry: 3).update_badge_json_clone(badge_id, json_clone)
      end
    end
  end
  
  def remove_from_badge
    if context != 'badge_async'
      Tag.delay(retry: 3).update_badge_json_clone(badge_id, json_clone, true)
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
end
