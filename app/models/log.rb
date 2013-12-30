class Log
  include Mongoid::Document
  include Mongoid::Timestamps
  include StringTools

  # === CONSTANTS === #
  
  VALIDATION_STATUS_VALUES = ['incomplete', 'requested', 'withdrawn', 'validated']
  ISSUE_STATUS_VALUES = ['unissued', 'issued', 'retracted']
  
  # === RELATIONSHIPS === #

  belongs_to :badge
  belongs_to :user

  # === FIELDS & VALIDATIONS === #

  field :validation_status,       type: String
  field :issue_status,            type: String
  field :show_on_profile,         type: Boolean
  field :private_log,             type: Boolean
  field :detached_log,            type: Boolean

  field :wiki,                    type: String
  field :wiki_sections,           type: Array
  field :wiki_versions,           type: Array

  field :date_requested,          type: Time
  field :date_withdrawn,          type: Time
  field :date_issued,             type: Time
  field :date_retracted,          type: Time
  field :date_sent_to_backpack,   type: Time

  field :validation_count,        type: Integer
  field :rejection_count,         type: Integer
  field :next_entry_number,       type: Integer
  field :current_user,        type: String # used when logging wiki_versions
  field :current_username,   type: String # used when logging wiki_versions

  validates :badge, presence: true
  validates :user, presence: true
  validates :validation_status, inclusion: { in: VALIDATION_STATUS_VALUES, 
                                message: "%{value} is not a valid badge validation status" }
  validates :issue_status, inclusion: { in: ISSUE_STATUS_VALUES, 
                                message: "%{value} is not a valid badge issue status" }
  
  # Which fields are accessible?
  attr_accessible :badge, :user, :show_on_profile, :private_log, :detached_log, :date_requested, 
    :date_withdrawn, :date_sent_to_backpack, :wiki, :current_user, :current_username

  # === CALLBACKS === #

  before_validation :set_default_values, on: :create
  after_validation :update_stati
  after_validation :update_wiki_sections
  after_validation :update_wiki_versions, on: :update # Don't store the first (default) value

  # === LOG METHODS === #

  def to_param
    user? ? user.username : _id
  end

  # Adds a generic validation from the specified user
  # NOTE: Doesn't work for new records.
  def add_validation(validating_user, validation_summary, validation_body)
    # FIXME: After adding entries come back and make this work properly (insert a log entry)
    if !new_record?
      self.validation_count += 1
      self.save!
    end
  end

protected
  
  def set_default_values
    self.validation_status ||= 'incomplete'
    self.issue_status ||= 'unissued'
    self.show_on_profile ||= true
    self.private_log ||= false
    self.detached_log ||= false
    self.wiki ||= APP_CONFIG['default_log_wiki']
    self.validation_count ||= 0
    self.rejection_count ||= 0
  end

  # Updates validation & issue status values
  def update_stati
    if !currently_validated?
      # First update the validation status if needed
      if validation_status == 'validated'
        if date_requested.nil?
          self.validation_status = 'incomplete'
        else
          if date_withdrawn.nil?
            self.validation_status = 'requested'
          else
            self.validation_status = 'withdrawn'
          end
        end
      elsif date_withdrawn_changed? && !date_withdrawn.nil?
        self.validation_status = 'withdrawn'
      elsif date_requested_changed? && !date_requested.nil?
        self.validation_status = 'requested'
      end
      
      # Then update the issue status if needed
      if issue_status == 'issued'
        issue_status = 'retracted'
        date_retracted = Time.now
      end 
    else
      # First update the validation status if needed
      if validation_status != 'validated'
        self.validation_status = 'validated'
      end

      # Then update the issue status if needed
      if issue_status != 'issued'
        self.issue_status = 'issued'
        self.date_issued = Time.now
        self.date_retracted = nil
      end
    end
  end

  def update_wiki_sections
    if wiki_changed?
      self.wiki_sections = linkify_text(wiki, badge.group, self).split(SECTION_DIVIDER_REGEX)
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

  # This is an internal-only function that checks if the log is
  # validated based on the current threshold & counts.
  def currently_validated?
    validation_threshold = 1 # default value (for tests and such)
    if badge && badge.expert_logs
      validation_threshold = badge.expert_logs.count
      if badge.group && badge.group.validation_threshold
        validation_threshold = [validation_threshold, badge.group.validation_threshold].min
      end
    end
    
    # Return value = 
    (validation_count - rejection_count) >= validation_threshold
  end

end
