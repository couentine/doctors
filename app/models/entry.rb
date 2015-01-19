class Entry
  include Mongoid::Document
  include Mongoid::Timestamps
  include JSONFilter
  include StringTools

  # === CONSTANTS === #
  
  MAX_SUMMARY_LENGTH = 100
  TYPE_VALUES = ['post', 'validation']
  JSON_FIELDS = [:log, :creator, :parent_tag, :entry_number, :summary, :type, :log_validated, 
    :body_sections, :tags, :tags_with_caps]
  
  # === RELATIONSHIPS === #

  belongs_to :log
  belongs_to :tag
  belongs_to :creator, inverse_of: :created_entries, class_name: "User"

  # === FIELDS & VALIDATIONS === #

  field :entry_number,        type: Integer
  field :summary,             type: String
  field :private,             type: Boolean
  field :type,                type: String
  field :log_validated,       type: Boolean
  field :parent_tag,          type: String

  field :body,                type: String
  field :body_versions,       type: Array
  field :body_sections,       type: Array
  field :tags,                type: Array
  field :tags_with_caps,      type: Array

  field :current_user,        type: String
  field :current_username,    type: String
  field :flags,                 type: Array

  validates :log, presence: true
  validates :creator, presence: true
  validates :entry_number, presence: true, uniqueness: { scope: :log }
  validates :summary, presence: true, length: { within: 3..MAX_SUMMARY_LENGTH }
  validates :type, inclusion: { in: TYPE_VALUES, 
                                message: "%{value} is not a valid entry type" }

  # Which fields are accessible?
  attr_accessible :parent_tag, :summary, :private, :log_validated, :body

  # === CALLBACKS === #

  before_validation :set_default_values, on: :create
  before_save :process_parent_tag
  before_save :update_body_sections
  before_save :update_body_versions # DO store the first value since it comes from the user
  after_create :send_notifications
  after_destroy :check_log_validation_counts
  
  # === ENTRY METHODS === #

  def to_param
    entry_number || _id
  end

  # Returns a number representing the updated_at date relative to the learner's start date
  # Example: if updated_at == log.date_started, return = 1 (learner's first week)
  def learner_week_updated_at
    ((updated_at.to_date - log.date_started.to_date).to_f / 3600 / 7).ceil
  end
  def learner_week_created_at
    ((created_at.to_date - log.date_started.to_date).to_f / 3600 / 7).ceil
  end

  # Return Values = [:learner_post, :expert_post, :validation]
  def category
    if type == 'validation'
      :validation
    elsif (creator != log.user) || (log.date_issued && (self.created_at > log.date_issued))
      :expert_post
    else
      :learner_post
    end
  end

  # Return Values = [:learner, :expert]
  def entry_creator_type
    if log.badge.nil?
      :learner
    else
      expert_date = creator.expert_date log.badge
      if expert_date && (created_at > expert_date)
        :expert
      else
        :learner
      end
    end
  end

  # Return Values = [:learner, :expert]
  def log_user_type
    if log.badge.nil?
      :learner
    else
      expert_date = log.user.expert_date log.badge
      if expert_date && (created_at > expert_date)
        :expert
      else
        :learner
      end
    end
  end

  # Returns a symbol representing the widest group to which this post is visible
  # NOTE: A post is ALWAYS visible to the creator and log owner (the :users).
  # Return values = [:users, :experts, :members, :anonymous]
  def visibility
    if self.private
      return (log.detached_log) ? :users : :experts
    elsif log.public?
      return :anonymous
    elsif log.detached_log
      return :users
    else
      return :members
    end
  end

  # Uses the return value of the visibility method to determine if this user can see the log entry
  # NOTE: It's ok if user is nil
  def visible_to?(user)
    if (self.visibility == :anonymous) || (user == self.creator) || (user == self.log.user) \
      || (!user.nil? && (user.admin?))
      return true
    elsif user && (self.visibility != :users)
      if self.visibility == :experts
        return user.expert_of?(self.log.badge)
      else # :members
        return user.member_of?(self.log.badge.group) || user.admin_of?(self.log.badge.group)
      end
    else # anonymous user / users only visibility
      return false
    end 
  end

protected
  
  def set_default_values
    self.private = false if private.nil?
    self.entry_number ||= log.next_entry_number if log
  end

  # Sets tag relationship based on parent_tag string
  def process_parent_tag
    if !parent_tag.blank? && parent_tag_changed? && !log.badge.nil?
      matched_tags = log.badge.tags.where(name: parent_tag.downcase)
      if matched_tags.count > 0
        self.tag = matched_tags.first
      else
        t = Tag.new
        t.badge = log.badge
        t.name_with_caps = parent_tag
        t.name = parent_tag.downcase
        t.wiki = ''
        t.current_user = current_user
        t.current_username = current_username
        if log.badge.tag_display_name(t.name).nil?
          t.display_name = detagify_string(t.name_with_caps)
          # This tag was invented by the current user so leave the database default editability
        else
          t.display_name = log.badge.tag_display_name(t.name)
          # This tag is one of the official requirements so set the editability same as the badge
          t.editability = log.badge.editability
        end
        
        t.save
        self.tag = t
      end
    end
  end

  def update_body_sections
    if body_changed? || summary_changed?
      body_result = linkify_text(body, log.badge.group, log.badge)
      summary_result = linkify_text(summary, log.badge.group, log.badge)
      
      if body_changed?
        self.body_sections = body_result[:text].split(SECTION_DIVIDER_REGEX)
      end
      
      # The entry tags should be a concatenation of the summary and body tags
      self.tags = [body_result[:tags], summary_result[:tags]].flatten.uniq
      self.tags_with_caps = [body_result[:tags_with_caps], summary_result[:tags_with_caps]]\
        .flatten.uniq
    end
  end

  def update_body_versions
    if body_changed?
      current_version_row = { :body => body, :user => current_user, 
                              :username => current_username, :updated_at => Time.now,
                              :updated_at_text => Time.now.strftime("%-m/%-d/%y at %l:%M%P") }

      if body_versions.nil? || (body_versions.length == 0)
        self.body_versions = [current_version_row]
      elsif body_versions.last[:body] != body
        self.body_versions << current_version_row
      end
    end
  end

  def send_notifications
    # Note: The created_at condition is to filter out sample_data & migrations
    if created_at > (Time.now - 2.hours)
      if (type == 'validation') && (log.user != creator)
        UserMailer.log_validation_received(log.user, creator, \
          log.badge.group, log.badge, log, self).deliver 
      end
    end
  end

  # Update the log if this was a validation
  def check_log_validation_counts
    if type == 'validation'
      if log_validated
        log.validation_count -= 1
      else
        log.rejection_count -= 1
      end
      log.save
    end
  end

end