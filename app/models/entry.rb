class Entry
  include Mongoid::Document
  include Mongoid::Timestamps
  include StringTools

  # === CONSTANTS === #
  
  MAX_SUMMARY_LENGTH = 140
  TYPE_VALUES = ['post', 'validation']
  
  # === RELATIONSHIPS === #

  belongs_to :log
  belongs_to :creator, inverse_of: :entries, class_name: "User"

  # === FIELDS & VALIDATIONS === #

  field :entry_number,        type: Integer
  field :summary,             type: String
  field :private,             type: Boolean
  field :type,                type: String
  field :log_validated,       type: Boolean

  field :body,                type: String
  field :body_versions,       type: Array
  field :body_sections,       type: Array

  field :current_user,        type: String
  field :current_username,    type: String
  field :flags,                 type: Array

  validates :log, presence: true
  validates :creator, presence: true
  validates :entry_number, presence: true, uniqueness: { scope: :log }
  validates :summary, presence: true, length: { within: 3..MAX_SUMMARY_LENGTH }
  validates :type, inclusion: { in: TYPE_VALUES, 
                                message: "%{value} is not a valid entry type" }
  validates :creator, uniqueness: { scope: :log }, if: "type=='validation'"

  # Which fields are accessible?
  attr_accessible :summary, :private, :log_validated, :body

  # === CALLBACKS === #

  before_validation :set_default_values, on: :create
  before_save :update_body_sections
  before_save :update_body_versions # DO store the first value since it comes from the user
  after_create :increment_log_next_entry_number
  after_create :process_new_validation
  after_create :send_notifications
  after_save :process_updated_validation, on: :update

  # === ENTRY METHODS === #

  def to_param
    entry_number || _id
  end

  # Returns a number representing the updated_at date relative to the learner's start date
  # Example: if updated_at == log.date_started, return = 1 (learner's first week)
  def learner_week_updated_at
    ((updated_at.to_date - log.date_started.to_date).to_f / 7).ceil
  end

protected
  
  def set_default_values
    self.private ||= false
    self.entry_number ||= log.next_entry_number if log

    true # don't return false! that causes an error
  end

  def update_body_sections
    if body_changed?
      self.body_sections = linkify_text(body, log.badge.group, log.badge).split(SECTION_DIVIDER_REGEX)
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

  def increment_log_next_entry_number
    log.next_entry_number += 1
    log.save!
  end

  # Updates the validation_count / rejection_count fields as appropriate
  def process_new_validation
    if type == 'validation'
      if log_validated
        log.validation_count += 1
      else
        log.rejection_count += 1
      end
      log.save!
    end
  end

  # Updates the validation_count / rejection_count fields as appropriate
  # Only updates the counts if log_validated changes
  def process_updated_validation
    if (type == 'validation') && log_validated_changed?
      if log_validated
        # we've changed FROM a rejection TO a validation
        log.validation_count += 1
        log.rejection_count -= 1
      else
        # we've changed FROM a validation TO a rejection
        log.validation_count -= 1
        log.rejection_count += 1
      end
      log.save!
    end
  end

  def send_notifications
    # Note: The created_at condition is to filter out sample_data & migrations
    if created_at > (Time.now - 1.hour)
      if type == 'validation'
        UserMailer.log_validation_received(log.user, creator, \
          log.badge.group, log.badge, log, self)
      end
    end
  end

end