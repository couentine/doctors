class Badge
  include Mongoid::Document
  include Mongoid::Timestamps
  include JSONFilter
  include JSONTemplater
  include StringTools

  # === CONSTANTS === #
  
  MAX_NAME_LENGTH = 50
  MAX_URL_LENGTH = 50
  MAX_SUMMARY_LENGTH = 140
  MAX_TERM_LENGTH = 15
  RECENT_DATE_THRESHOLD = 10.days # Used to filter "recent" activity & changes
  IMAGE_KEY_IGNORE = '<<ignore>>'
  EDITABILITY_VALUES = ['experts', 'admins']
  AWARDABILITY_VALUES = ['experts', 'admins']
  VISIBILITY_VALUES = ['public', 'private', 'hidden']
  JSON_FIELDS = [:group, :name, :editability, :awardability, :info, :url, :url_with_caps,
    :created_at, :updated_at]
  JSON_MOCK_FIELDS = { 'description' => :summary, 'image' => :image_as_url, 
    'image_medium' => :image_medium_url, 'image_small' => :image_small_url, 
    'criteria' => :criteria_url, 'issuer' => :issuer_url, 'slug' => :url_with_caps,
    'full_url' => :badge_url, 'experts' => :expert_user_id_strings, 
    'learners' => :learner_user_ids_strings }

  JSON_TEMPLATES = {
    list_item: [:id, :name, :url, :url_with_caps, :summary, :validation_request_count, 
      :expert_count, :image_url, :image_medium_url, :image_small_url, :full_url, :full_path],
    group_list_item: [:id, :name, :url, :url_with_caps, :summary, :validation_request_count,
      :expert_count, :image_url, :image_medium_url, :image_small_url, :full_url, :full_path],
    api_v1: {
      everyone: [:id, :record_path, :parent_path, { :url => :slug }, { :url_with_caps => :slug_with_caps }], 
      can_see_record: [:name, :summary, :validation_request_count, :learner_count, :image_url, :image_medium_url, :image_small_url, 
        :full_url, { :full_path => :relative_url }, :current_user_permissions]
    }
  }
  
  # Below are the badge-level fields included in the clone
  # NOTE: Badge image is automatically checked for changes and included
  CLONE_FIELDS = [:_id, :name, :summary, :editability, :awardability, :info, :url, :url_with_caps,
    :created_at, :updated_at, :visibility]

  # === INSTANCE VARIABLES === #

  attr_accessor :context # Used to prevent certain callbacks from firing in certain contexts
  attr_accessor :current_user_accessor # Used to set current user context during API calls

  # === RELATIONSHIPS === #

  belongs_to :group
  belongs_to :creator, inverse_of: :created_badges, class_name: "User"
  has_many :logs, dependent: :nullify
  has_many :tags, dependent: :destroy
  has_and_belongs_to_many :group_tags # DO NOT EDIT DIRECTLY: Use group_tag.add_badges/remove_badges

  # === FIELDS & VALIDATIONS === #

  field :name,                            type: String
  field :url,                             type: String
  field :url_with_caps,                   type: String
  field :summary,                         type: String
  field :word_for_expert,                 type: String, default: 'expert'
  field :word_for_learner,                type: String, default: 'learner'
  field :progress_tracking_enabled,       type: Boolean, default: true
  field :editability,                     type: String, default: 'admins'
  field :awardability,                    type: String, default: 'admins'
  field :visibility,                      type: String, default: 'public'
  field :send_validation_request_emails,  type: Boolean, default: true
  field :cloned_from_badge_id,            type: String # stored as a string id, not a relationship
  field :validation_threshold,            type: Integer, default: 1
  
  field :info,                            type: String
  field :info_sections,                   type: Array
  field :info_versions,                   type: Array
  field :info_tags,                       type: Array
  field :info_tags_with_caps,             type: Array

  field :topic_list_text,                 type: String # RETIRED field
  field :topics,                          type: Array, default: [] # RETIRED field

  field :image_frame,                     type: String
  field :image_icon,                      type: String
  field :image_color1,                    type: String
  field :image_color2,                    type: String
  field :image_attributions,              type: Array
  mount_uploader :custom_image,           S3BadgeUploader
  mount_uploader :designed_image,         S3BadgeUploader
  mount_uploader :direct_custom_image,    S3DirectBadgeUploader
  field :custom_image_key,                type: String
  
  field :current_user,                    type: String # used when logging info_versions
  field :current_username,                type: String # used when logging info_versions
  field :flags,                           type: Array

  field :move_to_group_id,                type: String
  
  field :json_clone,                      type: Hash, default: {}
  field :expert_user_ids,                 type: Array, default: []
  field :learner_user_ids,                type: Array, default: []
  field :all_user_ids,                    type: Array, default: []
  field :validation_request_count,        type: Integer, default: 0

  field :group_name,                      type: String # local cache of group info
  field :group_url,                       type: String # local cache of group info
  field :group_url_with_caps,             type: String # local cache of group info
  field :group_full_url,                  type: String # local cache of group info
  field :group_avatar_image_url,          type: String # local cache of group info
  field :group_avatar_image_medium_url,   type: String # local cache of group info
  field :group_avatar_image_small_url,    type: String # local cache of group info

  validates :name, presence: true, length: { maximum: MAX_NAME_LENGTH }
  validates :url_with_caps, presence: true, length: { within: 2..MAX_URL_LENGTH },
            uniqueness: { scope: :group },
            format: { with: /\A[\w-]+\Z/, 
              message: "can only contain letters, numbers, dashes and underscores" },
            exclusion: { in: APP_CONFIG['blocked_url_slugs'],
                         message: "%{value} is a specially reserved url." }
  validates :url, presence: true, length: { within: 2..MAX_URL_LENGTH },
    uniqueness: { scope: :group, 
      message:"The '%{value}' url is already being used in this group."},
    format: { with: /\A[\w-]+\Z/, 
      message: "can only contain letters, numbers, dashes and underscores" },
    exclusion: { in: APP_CONFIG['blocked_url_slugs'],
      message: "%{value} is a specially reserved url." }
  validates :summary, length: { maximum: MAX_SUMMARY_LENGTH }
  validates :word_for_expert, presence: true, length: { within: 3..MAX_TERM_LENGTH }
  validates :word_for_learner, length: { maximum: MAX_TERM_LENGTH }
  validates :editability, inclusion: { in: EDITABILITY_VALUES, 
    message: "%{value} is not a valid type of editability" }
  validates :awardability, inclusion: { in: AWARDABILITY_VALUES, 
    message: "%{value} is not a valid type of awardability" }
  validates :visibility, inclusion: { in: VISIBILITY_VALUES, 
    message: "%{value} is not a valid type of visibility" }
  validates :group, presence: true
  validates :creator, presence: true

  validate :move_to_group_id_is_valid
  
  # === CALLBACKS === #

  before_validation :set_default_values, on: :create
  before_validation :update_caps_field
  after_validation :copy_errors
  before_create :set_group_fields
  before_save :process_designed_image
  before_save :update_info_sections
  before_save :update_info_versions, on: :update # Don't store the first (default) value
  before_save :update_terms
  before_update :move_badge_if_needed
  before_save :update_json_clone_badge_fields_if_needed
  after_save :update_requirement_editability
  before_destroy :remove_from_group_and_user_cache
  after_destroy :clear_from_group_tags

  before_save :update_analytics

  # === BADGE FIND METHOD === #

  # `badge_identifier` can be the record id OR by a string of the format `group-url.badge-url`.
  def self.find(badge_identifier)
    badge = nil

    if badge_identifier.to_s.include? '.'
      badge_identifier_parts = badge_identifier.split('.')

      group = Group.find_by(url: badge_identifier_parts[0].to_s.downcase) rescue nil
      badge = group.badges.where(url: badge_identifier_parts[1].to_s.downcase).first if group
    elsif badge_identifier.to_s.match /^[0-9a-fA-F]{24}$/
      badge = super rescue nil
    end

    badge
  end

  # === BADGE MOCK FIELD METHODS === #
  # These are used to mock the presence of certain fields in the JSON output.

  def record_path
    "#{group_url || group.url}/#{url}"
  end

  def parent_path
    group_url || group.url
  end

  def image_as_url 
    image_url
  end

  def criteria_url
    "#{ENV['root_url']}/#{group_url_with_caps || group.url}/#{url}"
  end
  
  def issuer_url
    "#{ENV['root_url']}/#{group_url || group.url}.json"
  end

  def badge_url
    "#{ENV['root_url'] || 'https://www.badgelist.com'}" \
      + "/#{group_url_with_caps || group.url_with_caps}/#{url_with_caps}"
  end
  def full_url; badge_url; end

  def full_path
    "/#{group_url_with_caps || group.url_with_caps}/#{url_with_caps}"
  end

  def added_to_group_tag(group_tag)
    added = false;
    if self.group_tags.include? group_tag.name
      added = true;
    end
  end

  # Returns URL of the specified version of this badge's image
  # Valid version values are nil (defaults to full size), :medium, :small, :wide
  def image_url(version = nil)
    if image_mode == 'upload'
      custom_image_url(version) || 'blank.png'
    else
      designed_image_url(version) || 'blank.png'
    end
  end
  def image_medium_url; image_url(:medium); end
  def image_small_url; image_url(:small); end

  # Returns a stringified version of learner_user_ids
  def learner_user_ids_strings
    if learner_user_ids.blank?
      []
    else
      learner_user_ids.map{ |user_id| user_id.to_s }
    end
  end

  # Returns a stringified version of expert_user_ids
  def expert_user_id_strings
    if expert_user_ids.blank?
      []
    else
      expert_user_ids.map{ |user_id| user_id.to_s }
    end
  end

  # Uses current_user_accessor
  def current_user_can_see_badge
    if current_user_accessor
      (visibility == 'public') || current_user_accessor.admin || current_user_accessor.admin_of?(group_id)    \
      || ((visibility == 'private') && current_user_accessor.member_of?(group_id))                            \
      || ((visibility == 'hidden') && current_user_accessor.learner_or_expert_of?(id))
    else
      false
    end
  end

  # This is used by the API and requires that the current_user model attribute be set
  def current_user_permissions
    if current_user_accessor
      {
        can_see_record: current_user_can_see_badge,
        is_learner: learner_user_ids.include?(current_user_accessor.id),
        is_expert: expert_user_ids.include?(current_user_accessor.id)
      }
    else
      {
        can_see_record: current_user_can_see_badge,
        is_learner: false,
        is_expert: false
      }
    end
  end

  # === BADGE TERMINOLOGY METHODS === #
  # These are shortcuts to the various inflections of the word_for_xxx fields

  def expert; word_for_expert || 'expert'; end
  def experts; expert.pluralize; end
  def Expert; expert.titleize; end
  def Experts; experts.titleize; end

  def learner; word_for_learner || 'learner'; end
  def learners; learner.pluralize; end
  def Learner; learner.titleize; end
  def Learners; learners.titleize; end

  # NOTE: The current language no longer makes a linguistic distinction based on progress tracking.
  def log; (tracks_progress?) ? 'portfolio' : 'portfolio'; end
  def progress_log; (tracks_progress?) ? 'badge portfolio' : 'badge portfolio'; end

  def awarders;  (awardability == 'experts') ? experts : 'admins'; end
  def badge_awarders;  (awardability == 'experts') ? "badge #{experts}" : 'group admins'; end

  # Returns hash = {
  #   icon: fa-icon,
  #   label: one_or_two_word_summary_of_current_status,
  #   summary: contents_of_detail_tooltip
  # }
  def visibility_details
    if visibility == 'hidden'
      { icon: 'fa-eye-slash', label: 'Hidden', 
        summary: "Only visible to badge #{learners}, badge #{experts} and group admins." }
    elsif visibility == 'private'
      { icon: 'fa-users', label: 'Private', summary: "Only visible to group members." }
    else
      { icon: 'fa-globe', label: 'Public', summary: "Visible to everyone." }
    end
  end

  # This updates all of the user info cache fields on the log from the supplied user record
  def update_group_fields_from(group_record)
    self.group_name = group_record.name
    self.group_url = group_record.url
    self.group_url_with_caps = group_record.url_with_caps
    self.group_full_url = group_record.group_url
    self.group_avatar_image_url = group_record.avatar_image_url
    self.group_avatar_image_medium_url = group_record.avatar_image_medium_url
    self.group_avatar_image_small_url = group_record.avatar_image_small_url
  end

  # === CLONE CREATION METHOD === #

  # Creates a badge in the specified group from its json clone
  # Use the badge_context parameter to set the 'context' used when creating and updating the badge
  # Returns a hash with two keys:
  #  'success' => true or false
  #  'error_message' => string (if !success)
  #  'json_clone' => the json clone of the newly created badge (if success)
  def self.create_from_json_clone(creator, group, badge_json_clone, badge_context = nil)
    result = { 'success' => true, 'error_message' => nil }

    begin
      # First create the badge and assign the relationship fields
      badge = Badge.new
      badge.context = badge_context
      badge.group = group
      badge.creator = creator
      badge.current_user = creator
      badge.current_username = creator.username

      # Now assign the fields from the json clone and create the badge
      badge.cloned_from_badge_id = badge_json_clone['_id']
      badge.name = badge_json_clone['name']
      badge.summary = badge_json_clone['summary']
      badge.url = badge_json_clone['url']
      badge.url_with_caps = badge_json_clone['url_with_caps']
      badge.awardability = badge_json_clone['awardability'] || 'admins'
      badge.editability = badge_json_clone['editability'] || 'admins'
      badge.visibility = badge_json_clone['visibility'] || 'public'
      badge.info = badge_json_clone['info']
      badge.remote_custom_image_url = badge_json_clone['image_url']
      badge.custom_image_key = Badge::IMAGE_KEY_IGNORE # necessary to cause display of custom image
      badge.save!

      # Create the wiki & requirement pages
      (badge_json_clone['pages'] || []).each do |tag_item|
        new_tag = Tag.new()
        new_tag.badge = badge
        new_tag.type = tag_item['type']
        new_tag.sort_order = tag_item['sort_order']
        new_tag.name = tag_item['name']
        new_tag.display_name = tag_item['display_name']
        new_tag.name_with_caps = tag_item['name_with_caps']
        new_tag.summary = tag_item['summary']
        new_tag.format = tag_item['format']
        new_tag.privacy = tag_item['privacy']
        new_tag.editability = tag_item['editability']
        new_tag.wiki = tag_item['wiki']

        new_tag.context = 'badge_async' # prevent the badge update callback from firing
        new_tag.save if new_tag.valid?

        # Update the pages branch of the badge json clone
        badge.update_json_clone_tag new_tag.json_clone
      end

      # Finally save the badge json add the json clone to the result
      badge.save!
      result['json_clone'] = badge.json_clone
    rescue Exception => e
      result['success'] = false
      result['error_message'] = "Error creating badge: #{e}"
      result['badge'] = badge
    end

    result
  end

  # === ASYNC CLASS METHODS === #

  # Creates a new badge asynchronously and returns the id of a poller
  # The params and requirement list args should be same as those passed to badges_controller#create
  def self.create_async(group_id, creator_id, badge_params, requirement_list)
    poller = Poller.new
    poller.save
    Badge.delay(queue: 'high', retry: false).do_create_async(group_id, creator_id, badge_params, 
      requirement_list, poller.id)
    poller.id
  end
  
  # Powers the create_async method above. Not intended to be run directly but could be.
  # Example of badge creation in a console:
  #   g, u = Group.first, User.first
  #   bp = ActionController::Parameters.new({ name: 'Test Badge 1', summary: 'Testing', 
  #     url_with_caps: 'test-badge-1', image_frame: 'circle', image_icon: 'pen', 
  #     image_color1: 'FFFFFF', image_color2: '000000' })
  #   rl = [{ display_name:'Item 1', format:'text' }, { display_name:'Item 2', format:'image' }]
  #   b = Badge.do_create_async(g.id, u.id, bp, rl)
  def self.do_create_async(group_id, creator_id, badge_params, requirement_list, poller_id = nil)
    # begin
      # First query for the core records
      poller = Poller.find(poller_id) rescue nil
      group = Group.find(group_id)
      creator = User.find(creator_id)

      badge = Badge.new(badge_params.permit(BadgesController::PERMITTED_PARAMS))
      badge.group = group
      badge.creator = creator
      badge.current_user = creator
      badge.current_username = creator.username

      if !badge.custom_image_key.blank? && (badge.custom_image_key != IMAGE_KEY_IGNORE)
        badge.update_custom_image
      end

      # Save the badge and then update the requirements if successful
      badge.save!
      badge.update_requirement_list(requirement_list)
        
      # Then save the results
      if poller
        poller.status = 'successful'
        poller.message = "The '#{badge.name}' badge has been successfully created!"
        poller.data = { badge_id: badge.id.to_s }
        poller.save
      end
    # rescue Exception => e
    #   if poller
    #     poller.status = 'failed'
    #     poller.message = 'An error occurred while trying to create the badge, ' \
    #       + "please try again. (Error message: #{e})"
    #     poller.save
    #   else
    #     throw e
    #   end
    # end
  end

  def update_async(current_user_id, badge_params, requirement_list)
    poller = Poller.new
    poller.waiting_message = 'Saving changes to badge...'
    poller.save
    Badge.delay(queue: 'high', retry: false).do_update_async(id, current_user_id, badge_params, 
      requirement_list, poller.id)
    poller.id
  end

  # Powers the update_async method above. Not intended to be run directly but could be.
  def self.do_update_async(badge_id, current_user_id, badge_params, requirement_list, 
      poller_id = nil)
    begin
      # First query for the core records
      poller = Poller.find(poller_id) rescue nil
      badge = Badge.find(badge_id)
      original_custom_image_key = badge.custom_image_key
      user = User.find(current_user_id)
      
      badge.current_user = user
      badge.current_username = user.username

      # Save the badge and then update the requirements if successful
      badge.update_attributes!(badge_params.permit(BadgesController::PERMITTED_PARAMS))
      badge.update_requirement_list(requirement_list)

      # Update the custom image if needed
      if (badge.custom_image_key != original_custom_image_key) && !badge.custom_image_key.blank? \
          & (badge.custom_image_key != IMAGE_KEY_IGNORE)
        badge.update_custom_image
        badge.save!
      end

      # Then save the results
      if poller
        poller.status = 'successful'
        poller.message = "The '#{badge.name}' badge has been successfully updated!"
        poller.redirect_to = "/#{badge.group.url_with_caps}/#{badge.url_with_caps}"
        poller.data = { badge_id: badge.id.to_s }
        poller.save
      end
    rescue Exception => e
      if poller
        poller.status = 'failed'
        poller.message = 'An error occurred while trying to update the badge, ' \
          + "please try again. (Error message: #{e})"
        poller.redirect_to = "/#{badge.group.url_with_caps}/#{badge.url_with_caps}"
        poller.data = { badge_id: badge.id.to_s }
        poller.save
      else
        throw e
      end
    end
  end

  def self.update_validation_request_count(badge_ids)
    badge = Badge.find(badge_id)
    badge.update_validation_request_count
    badge.timeless.save if badge.changed?
  end

  def update_validation_request_count
    self.validation_request_count = requesting_learner_logs.count

    # Now update all of the group tags
    group_tags.each do |group_tag|
      group_tag.update_validation_request_count_for(self)
      group_tag.timeless.save
    end
  end

  # Removes badge from various user cache fields
  # NOTE: We have to pass the log_ids and group_id since the badge itself will have been deleted
  def self.clear_user_badge_caches(log_ids, badge_id, group_id)
    group = Group.find(group_id)
    user_ids = Log.where(:id.in => log_ids).map{ |log| log.user_id }
    users = User.where(:id.in => user_ids)

    users.each do |user|
      user.all_badge_ids.delete badge_id if user.all_badge_ids.include? badge_id
      user.learner_badge_ids.delete badge_id if user.learner_badge_ids.include? badge_id
      user.requested_badge_ids.delete badge_id if user.requested_badge_ids.include? badge_id
      user.expert_badge_ids.delete badge_id if user.expert_badge_ids.include? badge_id

      user.update_validation_request_count_for group
      
      user.timeless.save
    end
  end

  # === INSTANCE METHODS === #

  def to_param
    url_with_caps
  end

  # Returns 'design' or 'upload' based on whether there is an uploaded badge image
  # NOTE: Sometimes custom image gets set randomly so we have to verify the presence of the custom
  #       image key as well, otherwise it returns a false positive in some cases.
  def image_mode
    (!custom_image_key.blank? && custom_image?) ? 'upload' : 'design'
  end

  def tracks_progress?
    return progress_tracking_enabled.nil? || (progress_tracking_enabled == true)
  end

  def has_overview?
    !info_versions.blank? && !info.blank?
  end

  def has_requirements?
    !requirements_json_clone.blank?
  end

  def has_wikis?
    !wikis_json_clone.blank?
  end

  # Returns boolean indicating whether the specified user has permission to award this badge
  # Does NOT query any additional records, only references badge and user fields
  def can_be_awarded_by?(user)
    user.admin || user.admin_of_ids.include?(group_id) \
      || ((awardability == 'experts') && expert_user_ids.include?(user.id))
  end

  # Return tags with type = 'requirement' sorted by sort_order
  def requirements
    tags.where(type: 'requirement').order_by(:sort_order.asc)
  end

  # Returns all requirement entries from the pages branch of the badge json clone (sorted in order)
  def requirements_json_clone
    if json_clone && json_clone['pages']
      json_clone['pages'].select{ |tag_item| tag_item['type'] == 'requirement' }\
        .sort_by{ |tag_item| tag_item['sort_order'] } 
    else
      []
    end
  end

  # Return all non-requiremetn tags sorted by name
  def wikis
    tags.where(:type.ne => 'requirement').order_by(:name.asc)
  end

  # Returns all wiki entries from the pages branch of the badge json clone (sorted by name)
  def wikis_json_clone
    if json_clone && json_clone['pages']
      json_clone['pages'].select{ |tag_item| tag_item['type'] == 'wiki' }\
        .sort_by{ |tag_item| tag_item['name'] } 
    else
      []
    end
  end

  def learner_count
    learner_user_ids.count
  end

  def expert_count
    expert_user_ids.count
  end

  # Returns all non-validated logs, sorted by user name
  def learner_logs
    logs.where(:validation_status.ne => 'validated', detached_log: false).asc(:user_name)
  end

  # Returns all validated logs, sorted by user name
  def expert_logs
    logs.where(validation_status: 'validated', detached_log: false).asc(:user_name)
  end

  # Returns all learners who are currently requesting validation
  # Reverse sorts logs by request/withdrawal date
  def requesting_learner_logs
    logs.where(validation_status: 'requested', detached_log: false).desc(:date_withdrawn)
  end

  # Returns all recently validated experts, reverse sorted by issue date
  def new_expert_logs
    recent_date = Time.now - RECENT_DATE_THRESHOLD
    logs.where(validation_status: 'validated', :date_issued.gt => recent_date, \
      detached_log: false).desc(:date_issued)
  end

  # Adds a learner to the badge by creating or reattaching a log for them
  # NOTE: If there is already a detached log this function will reattach it. If there is already a normal log it will not be changed.
  # Return value = the newly created/reattached log
  # OPTIONS:
  # - date_started: Defaults to nil. If set, overrides the log.date_started fields
  # - update_user_async: Defaults to false. Set this to update the user record asyncronously.
  #                      Search to the log model for 'badge_add_async' for specifics.
  def add_learner(user, options = {})
    the_log = logs.find_by(user_id: user.id) rescue nil
    update_badge = false

    log_context = (options[:update_user_async]) ? 'badge_add_async' : 'badge_add'
    
    if the_log
      if the_log.detached_log
        the_log.detached_log = false
        the_log.show_on_badge = user.get_group_settings_for(group_id)['show_on_badges']
        the_log.show_on_profile = user.get_group_settings_for(group_id)['show_on_profile']
        the_log.context = log_context # This will suppress the badge update callback
        the_log.save
        the_log.context = nil # CLEAR THIS OUT so it doesn't mess stuff up
        update_badge = true
      end
    else
      the_log = Log.new(date_started: options[:date_started])
      the_log.badge = self
      the_log.user = user
      the_log.show_on_badge = user.get_group_settings_for(group_id)['show_on_badges']
      the_log.show_on_profile = user.get_group_settings_for(group_id)['show_on_profile']
      the_log.context = log_context # This will suppress the badge update callback
      the_log.save
      the_log.context = nil # CLEAR THIS OUT so it doesn't mess stuff up
      update_badge = true
    end

    if update_badge
      self.all_user_ids << user.id unless self.all_user_ids.include? user.id
      if the_log.validation_status == 'validated'
        self.expert_user_ids << user.id unless self.expert_user_ids.include? user.id
        self.learner_user_ids.delete user.id if self.learner_user_ids.include? user.id
      else
        self.expert_user_ids.delete user.id if self.expert_user_ids.include? user.id
        self.learner_user_ids << user.id unless self.learner_user_ids.include? user.id
      end

      self.timeless.save if self.changed?
    end

    the_log
  end

  # Refresh the topic_list_text from the requirements list
  def refresh_topic_list_text
    requirement_items = requirements

    if requirement_items.blank?
      self.topic_list_text = ''
    else
      self.topic_list_text = requirement_items.map{ |tag| tag.display_name }.join("\n")
    end
  end

  # Call this method to return requirement_list JSON-formatted string
  def build_requirement_list
    if new_record?
      return '[]'
    else
      list = []
      requirements.each do |tag|
        list << {
          id: tag.id.to_s,
          display_name: tag.display_name,
          summary: (tag.summary.blank? || (tag.summary == 'null')) ? '' : tag.summary,
          format: tag.format,
          privacy: tag.privacy,
          is_deleted: false
        }
      end
      
      return list.to_json
    end
  end

  # Pass the 'pages' property from the badge json clone and this method transforms it and passes
  # it to the update_requirement_list method
  # NOTE: This method is not currently being used (it turned out to not be necessary for 
  #       creating from json), but I'm leaving it around in case it's useful later.
  def update_requirement_list_from_json_clone(badge_json_clone_pages)
    requirement_list = badge_json_clone_pages.select{ |tag_item| tag_item['type']=='requirement' }\
      .sort_by{ |tag_item| tag_item['sort_order'] }
    update_requirement_list(requirement_list, true)
  end

  # Call this method to processes changes to the requirement_list 
  # Also updates progress_tracking_enabled (and saves the badge record if needed)
  # NOTE: If requirement_list is blank then this method does nothing
  def update_requirement_list(requirement_list, already_parsed = false)
    unless requirement_list.blank?
      # First parse the requirement list from JSON
      if already_parsed
        parsed_list = requirement_list
      else
        parsed_list = JSON.parse requirement_list rescue nil
      end
      new_requirement_count = 0 # used later to set progress tracking boolean
      
      if parsed_list.instance_of?(Array) # false if nil
        tag_ids, tag_names, matched_tag_names = [], [], []
        requirement_id_map, requirement_name_map = {}, {} # map[tag name/id] = requirement item
        
        # Run through and build a list of tag ids and tag names to query
        parsed_list.each_with_index do |requirement, index|
          unless requirement['display_name'].blank?
            requirement['sort_order'] = index + 1
            requirement['name_with_caps'] = tagify_string(requirement['display_name'])
            requirement['name'] = requirement['name_with_caps'].downcase
            tag_names << requirement['name']
            requirement_name_map[requirement['name']] = requirement
            new_requirement_count += 1 unless requirement['is_deleted']
            
            unless requirement['id'].blank?
              tag_ids << requirement['id'] 
              requirement_id_map[requirement['id']] = requirement
            end
          end
        end

        # Query for all existing requirement tags as well as any other tags referenced in the list
        # (whether or not they are requirements)
        relevant_tags = tags.any_of({:id.in => tag_ids}, {:name.in => tag_names}, 
          {type: 'requirement'})

        # Run through and handle updates to existing tags
        relevant_tags.each do |tag|
          # First try to find requirement by id (for updating), then try by name (for promoting)
          r = requirement_id_map[tag.id.to_s] || requirement_name_map[tag.name]
          tag.context = 'badge_async' # this will prevent the badge update callback from firing

          if r # then this tag is being updated
            tag.type = (r['is_deleted']) ? 'wiki' : 'requirement'
            tag.sort_order = r['sort_order']
            tag.name = r['name']
            tag.display_name = r['display_name']
            tag.name_with_caps = r['name_with_caps']
            tag.format = r['format']
            tag.privacy = r['privacy']
            tag.summary = r['summary']
            tag.wiki = r['wiki'] unless r['wiki'].blank?

            tag.save if tag.changed? && tag.valid?
            matched_tag_names << tag.name # This will have the NEW name if it changed
          else # this tag is no longer in the requirement list, demote it
            tag.type = 'wiki'
            tag.save
          end
          
          # Update the pages branch of the badge json clone
          update_json_clone_tag tag.json_clone
        end
        
        # Now go back and create any requirement tags which are new
        requirement_name_map.each do |tag_name, r|
          unless matched_tag_names.include? tag_name
            new_tag = Tag.new()
            new_tag.badge = self
            new_tag.type = (r['is_deleted']) ? 'wiki' : 'requirement'
            new_tag.sort_order = r['sort_order']
            new_tag.name = r['name']
            new_tag.display_name = r['display_name']
            new_tag.name_with_caps = r['name_with_caps']
            new_tag.summary = r['summary']
            new_tag.format = r['format']
            new_tag.privacy = r['privacy']
            new_tag.wiki = r['wiki'] # NOTE: This is only set if creating from a json clone

            new_tag.context = 'badge_async' # prevent the badge update callback from firing
            new_tag.save if new_tag.valid?

            # Update the pages branch of the badge json clone
            update_json_clone_tag new_tag.json_clone
          end
        end
      end
      
      # The last step is to update progress tracking boolean if needed
      self.progress_tracking_enabled = (new_requirement_count > 0)
      self.save if self.changed?
    end
  end

  # Moves the badge to a new group and then asynchronously moves over group memberships
  def move_badge_to(new_group)
    if group_id != new_group.id
      self.group = new_group

      # Update the group cache fields
      self.update_group_fields_from new_group
      
      # Now run the bulk addition of members asynchronously (no poller for now)
      all_user_ids = logs.map{ |log| log.user_id }
      new_group.bulk_add_members(all_user_ids, true)
    end
  end

  # Regenerates the designed_image from the image frame, icon and color params and saves to s3
  # Does not update attribution fields
  def rebuild_designed_image
    badge_image = BadgeMaker.build_image(frame: image_frame, icon: image_icon, 
      color1: image_color1, color2: image_color2)
    badge_image_path = File.dirname(badge_image.path) + '/badge.png'  
    badge_image.write badge_image_path
    self.designed_image = File.open(badge_image_path)
    self.save!
  end

  # Sets the image url based on the supplied image key (defaults to the model value)
  # NOTE: You need to save the badge afterward to commit the new path to the DB.
  # NOTE #2: This may not be necessary... on 11/27 I discovered that reinstalling imagemagick in 
  #   my dev environment resolved the initial cause for this. Investigate later.
  def update_custom_image(image_key = custom_image_key)
    self.remote_custom_image_url = \
      "#{ENV['s3_asset_url']}/#{ENV['s3_bucket_name']}/#{image_key}"
  end

  # This will update the badge fields ONLY and leave the pages list untouched
  # Set the parameter to control whether the group is updated
  # NOTE: It will manually update the image_url field
  def update_json_clone_badge_fields(also_update_group_badge_cache = true)
    pages_backup = json_clone['pages']
    self.json_clone = self.as_json(use_default_method: true, only: CLONE_FIELDS, 
      methods: [:image_url, :image_medium_url, :image_small_url])
    self.json_clone['id'] = self.json_clone['_id'] = self.id.to_s # stringify
    self.json_clone['pages'] = pages_backup
    self.json_clone['created_at'] ||= Time.now
    self.json_clone['updated_at'] ||= Time.now

    if also_update_group_badge_cache
      group.update_badge_cache json_clone
      group.timeless.save
    end

    true
  end

  # This updates or deletes the json clone copy of the specified tag located in json_clone['pages']
  # If the specified tag does not exist it will be created
  # If is_deleted is true then the specified entry will be deleted
  def update_json_clone_tag(tag_json_clone, is_deleted = false)
    self.json_clone['pages'] = [] if json_clone['pages'].nil?
    tag_id = tag_json_clone['_id']
    tag_item_index = json_clone['pages'].index { |item| item["_id"] == tag_id }

    if tag_item_index
      if is_deleted # then delete this item
        self.json_clone['pages'].delete_at tag_item_index
      else # update this item
        self.json_clone['pages'][tag_item_index] = tag_json_clone
      end
    elsif !is_deleted # create this item
      self.json_clone['pages'] << tag_json_clone
    end
  end

protected
  
  def set_default_values
    self.info ||= APP_CONFIG['default_badge_info']
    self.flags ||= []
  end

  def update_caps_field
    if url_with_caps.nil?
      self.url = nil
    else
      self.url = url_with_caps.downcase
    end
  end

  def copy_errors
    if errors && !errors[:url].blank?
      errors[:name] = errors[:url]
    end
  end

  def set_group_fields
    update_group_fields_from group
  end

  def process_designed_image
    if !designed_image? || image_frame_changed? || image_icon_changed? || image_color1_changed? \
        || image_color2_changed?
      self.build_badge_image
    end

    true
  end

  def update_info_sections
    if info_changed?
      linkified_result = linkify_text(info, group, self)
      self.info_sections = linkified_result[:text].split(SECTION_DIVIDER_REGEX)
      self.info_tags = linkified_result[:tags]
      self.info_tags_with_caps = linkified_result[:tags_with_caps]
    end

    true
  end

  def build_badge_image
    # DEV NOTE: The technique I'm using below is weird and feels kind of hacky. I'm creating a 
    #           temp file and passing in the stringified tempfile to the field. There's another
    #           technique that I like better (used in rebuild_designed_image) which is simpler,
    #           but for some reason it wasn't working reliably, especially when making changes
    #           to an existing badge.  So for now this is it.

    # First build the image and manually write it to the designed_image property
    badge_image = BadgeMaker.build_image(frame: image_frame, icon: image_icon, 
      color1: image_color1, color2: image_color2)
    tempfile = Tempfile.open('designed_badge_image.png')
    tempfile.write(File.read(badge_image.path))
    tempfile.close
    env = { "CONTENT_TYPE" => "image/png" }
    headers = ActionDispatch::Http::Headers.new(env)
    # self.designed_image = S3BadgeUploader.new
    self.designed_image = ActionDispatch::Http::UploadedFile.new(tempfile: tempfile, \
      filename: "badge.png", type: 'image/png', head: headers)

    # Then store the attribution information 
    # Note: The parameters will only be missing for test data, randomization for users will happen
    #       client-side meaning that the potential for missing attribution info below is low.
    self.image_attributions = []
    frame_attribution = BadgeMaker.get_attribution :frames, image_frame
    icon_attribution = BadgeMaker.get_attribution :icons, image_icon
    self.image_attributions << frame_attribution unless frame_attribution.nil?
    self.image_attributions << icon_attribution unless icon_attribution.nil?
  end

  def update_info_versions
    if info_changed? && !new_record? && (info != APP_CONFIG['default_badge_info'])
      current_version_row = { :info => info, :user => current_user, 
                              :username => current_username, :updated_at => Time.now,
                              :updated_at_text => Time.now.strftime("%-m/%-d/%y at %l:%M%P") }

      if info_versions.nil? || (info_versions.length == 0)
        self.info_versions = [current_version_row]
      elsif info_versions.last[:info] != info
        self.info_versions << current_version_row
      end
    end
  end

  def update_terms
    if word_for_expert_changed?
      self.word_for_expert = word_for_expert.gsub(/[^ A-Za-z]/, ' ').gsub(/ {2,}/, ' ')\
        .strip.downcase.singularize
    end

    if word_for_learner_changed?
      if word_for_learner.blank?
        self.word_for_learner = nil
      else 
        self.word_for_learner = word_for_learner.gsub(/[^ A-Za-z]/, ' ').gsub(/ {2,}/, ' ')\
          .strip.downcase.singularize
      end
    end

    true
  end

  def update_json_clone_badge_fields_if_needed
    # First find the intersection of the fields to watch and the fields that have changed
    clone_field_names = CLONE_FIELDS.map{ |field_symbol| field_symbol.to_s }
    changed_clone_field_names = changed & clone_field_names

    if !changed_clone_field_names.blank? || (image_url != json_clone['image_url'])
      update_group = (context != 'group_async')
      update_json_clone_badge_fields update_group
    end
  end

  # If the badge editability is changed this method propogates that change to the requirement tags
  def update_requirement_editability
    if editability_changed?
      requirements.each do |tag|
        tag.editability = self.editability
        tag.timeless.save
      end
    end
  end

  def remove_from_group_and_user_cache
    # Only remove from group cache if we're not running from with an aync group operation context
    # NOTE: It currently isn't possible to delete badges in a group async operation
    if context != 'group_async'
      group.update_badge_cache json_clone, true
      group.timeless.save
    end

    # Now clear this badges presence from the user caches
    Badge.delay_for(5.seconds, queue: 'low').clear_user_badge_caches(log_ids, id, group_id)
  end

  # Makes async to group tag clearing method
  def clear_from_group_tags
    GroupTag.delay(queue: 'low').clear_deleted_badge_from_all(self.id)
  end

  # Validates that the destination group id points to a real group that is owned by the same user
  # as the current group
  def move_to_group_id_is_valid
    unless move_to_group_id.blank?
      new_group = Group.find(move_to_group_id) rescue nil
      
      if new_group.nil?
        errors.add(:move_to_group_id, " is not a valid Badge List group.")
      elsif (new_group.owner_id != group.owner_id)
        errors.add(:move_to_group_id, " is not a valid destination group. " \
          + "You can ony move this badge to a group you own.")
      elsif new_group.disabled?
        errors.add(:move_to_group_id, " is currently inactive and cannot host new badges.")
      end
    end
  end

  def move_badge_if_needed
    if !move_to_group_id.blank?
      new_group = Group.find(move_to_group_id)
      self.move_badge_to new_group
      self.move_to_group_id = nil
    end
  end

  #=== ANALYTICS ===#

  def update_analytics
    if new_record?
      IntercomEventWorker.perform_async({
        'event_name' => 'badge-create',
        'email' => creator.email,
        'user_id' => creator.id.to_s,
        'created_at' => Time.now.to_i,
        'metadata' => {
          'group_id' => group.id.to_s,
          'group_name' => group.name,
          'badge_id' => id.to_s,
          'badge_name' => name,
          'badge_url' => badge_url
        }
      })
    end
  end

end