class Badge
  include Mongoid::Document
  include Mongoid::Timestamps
  include JSONFilter
  include StringTools

  # === CONSTANTS === #
  
  MAX_NAME_LENGTH = 50
  MAX_URL_LENGTH = 50
  MAX_SUMMARY_LENGTH = 140
  MAX_TERM_LENGTH = 15
  RECENT_DATE_THRESHOLD = 10.days # Used to filter "recent" activity & changes
  EDITABILITY_VALUES = ['experts', 'admins']
  AWARDABILITY_VALUES = ['experts', 'admins']
  JSON_FIELDS = [:group, :name, :summary, :word_for_expert, :word_for_learner]
  JSON_MOCK_FIELDS = { 'description' => :summary, 'image' => :image_as_url, 
    'criteria' => :criteria_url, 'issuer' => :issuer_url, 'slug' => :url_with_caps }

  # === RELATIONSHIPS === #

  belongs_to :group
  belongs_to :creator, inverse_of: :created_badges, class_name: "User"
  has_many :logs, dependent: :nullify
  has_many :tags, dependent: :destroy

  # === FIELDS & VALIDATIONS === #

  field :name,                            type: String
  field :url,                             type: String
  field :url_with_caps,                   type: String
  field :summary,                         type: String
  field :word_for_expert,                 type: String, default: 'expert'
  field :word_for_learner,                type: String, default: 'learner'
  field :progress_tracking_enabled,       type: Boolean, default: true
  field :editability,                     type: String, default: 'experts'
  field :awardability,                    type: String, default: 'experts'
  field :send_validation_request_emails,  type: Boolean, default: 'true'
  
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
  field :image_url,                       type: String # RETIRED field
  field :image,                           type: Moped::BSON::Binary # stores the designed image
  field :image_wide,                      type: Moped::BSON::Binary

  field :image_attributions,              type: Array
  field :icon_search_text,                type: String # stores what user searched for b4 picking
  field :uploaded_image,                  type: String # powered by the carrierwave gem
  mount_uploader :uploaded_image,     ImageUploader

  field :current_user,                    type: String # used when logging info_versions
  field :current_username,                type: String # used when logging info_versions
  field :flags,                           type: Array

  field :move_to_group_id,                type: String

  validates :name, presence: true, length: { maximum: MAX_NAME_LENGTH }
  validates :url_with_caps, presence: true, length: { within: 2..MAX_URL_LENGTH },
            uniqueness: { scope: :group },
            format: { with: /\A[\w-]+\Z/, 
              message: "can only contain letters, numbers, dashes and underscores" },
            exclusion: { in: APP_CONFIG['blocked_url_slugs'],
                         message: "%{value} is a specially reserved url." }
  validates :url, presence: true, length: { within: 2..MAX_URL_LENGTH },
            uniqueness: { scope: :group },
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
  validates :group, presence: true
  validates :creator, presence: true

  validate :move_to_group_id_is_valid

  # Which fields are accessible?
  attr_accessible :name, :url_with_caps, :summary, :info, :word_for_expert, :word_for_learner,
    :editability, :awardability, :image_frame, :image_icon, :image_color1, :image_color2, 
    :icon_search_text, :topic_list_text, :uploaded_image, :remove_uploaded_image,
    :uploaded_image_cache, :send_validation_request_emails, :move_to_group_id
  
  # === CALLBACKS === #

  before_validation :set_default_values, on: :create
  before_validation :update_caps_field
  before_save :update_info_sections
  before_save :update_info_versions, on: :update # Don't store the first (default) value
  before_save :build_badge_image
  before_save :update_terms
  after_create :add_creator_as_expert
  after_save :update_requirement_editability
  before_update :move_badge_if_needed

  # === BADGE MOCK FIELD METHODS === #
  # These are used to mock the presence of certain fields in the JSON output.

  def image_as_url; "#{ENV['root_url']}/#{group.url}/#{url}.png"; end
  def criteria_url; "#{ENV['root_url']}/#{group.url}/#{url}"; end
  def issuer_url; "#{ENV['root_url']}/#{group.url}.json"; end

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

  def log; (tracks_progress?) ? 'log' : 'profile'; end
  def progress_log; (tracks_progress?) ? 'progress log' : 'badge profile'; end

  def awarders;  (awardability == 'experts') ? experts : 'admins'; end
  def badge_awarders;  (awardability == 'experts') ? "badge #{experts}" : 'group admins'; end

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
  def self.do_create_async(group_id, creator_id, badge_params, requirement_list, poller_id = nil)
    begin
      # First query for the core records
      poller = Poller.find(poller_id) rescue nil
      group = Group.find(group_id)
      creator = User.find(creator_id)
      
      # We need to Base64 decode the uploaded file if present (and build a new UploadedFile)
      if badge_params['uploaded_image']
        file = badge_params['uploaded_image']
        tempfile = Tempfile.new('file')
        tempfile.binmode
        tempfile.write(Base64.decode64(file.tempfile))
        badge_params['uploaded_image'] = \
          ActionDispatch::Http::UploadedFile.new(tempfile: tempfile, \
            filename: file.original_filename, type: file.content_type, head: file.headers)
      end

      badge = Badge.new(badge_params)
      badge.group = group
      badge.creator = creator
      badge.current_user = creator
      badge.current_username = creator.username

      # Save the badge and then update the requirements if successful
      badge.save!
      badge.update_requirement_list(requirement_list)
        
      # Then save the results
      if poller
        poller.status = 'successful'
        poller.message = "The '#{badge.name}' badge has been successfully created!"
        poller.data = { badge_id: badge.id }
        poller.save
      end
    rescue Exception => e
      if poller
        poller.status = 'failed'
        poller.message = 'An error occurred while trying to create the badge, ' \
          + "please try again. (Error message: #{e})"
        poller.save
      else
        throw e
      end
    end
  end

  # === INSTANCE METHODS === #

  def to_param
    url
  end

  # Returns 'design' or 'upload' based on whether there is an uploaded badge image
  def image_mode
    (uploaded_image.blank?) ? 'design' : 'upload'
  end

  def tracks_progress?
    return progress_tracking_enabled.nil? || (progress_tracking_enabled == true)
  end

  def has_overview?
    !info_versions.blank? && !info.blank?
  end

  def has_requirements?
    !requirements.blank?
  end

  def has_wikis?
    !wikis.blank?
  end

  # Return tags with type = 'requirement' sorted by sort_order
  def requirements
    tags.where(type: 'requirement').order_by(:sort_order.asc)
  end

  # Return all non-requiremetn tags sorted by name
  def wikis
    tags.where(:type.ne => 'requirement').order_by(:name.asc)
  end

  # Returns all non-validated logs, sorted by entry counts (user name would require queries)
  def learner_logs
    logs.where(:validation_status.ne => 'validated', detached_log: false).desc(:next_entry_number)
  end

  # Returns all validated logs, sorted by entry counts (user name would require queries)
  def expert_logs
    logs.where(validation_status: 'validated', detached_log: false).desc(:next_entry_number)
  end

  # Returns the email addresses of all waiting experts
  def waiting_expert_emails
    [group.invited_admins, group.invited_members].flatten.find_all do |item| 
      !item["validations"].blank? \
        && item["validations"].map{|v| v["badge"]}.include?(url)
    end.map{ |item| item["email"] }
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
  # NOTE: If there is already a detached log this function will reattach it
  # date_started: Defaults to nil. If set, overrides the log.date_started fields
  # Return value = the newly created/reattached log
  def add_learner(user, date_started = nil)
    the_log = logs.find_by(user: user) rescue nil
    
    if the_log
      if the_log.detached_log
        the_log.detached_log = false
        the_log.save
      end
    else
      the_log = Log.new(date_started: date_started)
      the_log.badge = self
      the_log.user = user
      the_log.save
    end

    the_log
  end

  # Returns the ACTUAL validation threshold based on the group settings AND the badge expert count
  def current_validation_threshold
    # NOTE: I'm removing this for now since it requires an extra query.
    return [expert_logs.count, 1].min
    
    # validation_threshold = expert_logs.count

    # if group && group.validation_threshold
    #   validation_threshold = [validation_threshold, group.validation_threshold].min
    # end

    # validation_threshold
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
          id: tag.id,
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

  # Call this method to processes changes to the requirement_list 
  # Also updates progress_tracking_enabled (and saves the badge record if needed)
  # NOTE: If requirement_list is blank then this method does nothing
  def update_requirement_list(requirement_list)
    unless requirement_list.blank?
      # First parse the requirement list from JSON
      parsed_list = JSON.parse requirement_list rescue nil
      new_requirement_count = 0 # used later to set progress tracking boolean
      
      if parsed_list.instance_of?(Array) # false if nil
        tag_ids, tag_names, matched_tag_names = [], [], []
        requirement_id_map, requirement_name_map = {}, {} # maps from tag name/id > requirement item
        
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
          # First try to find the requirement by id (for updating), then try by name (for promoting)
          r = requirement_id_map[tag.id.to_s] || requirement_name_map[tag.name]

          if r # then this tag is being updated
            tag.type = (r['is_deleted']) ? 'wiki' : 'requirement'
            tag.sort_order = r['sort_order']
            tag.name = r['name']
            tag.display_name = r['display_name']
            tag.name_with_caps = r['name_with_caps']
            tag.format = r['format']
            tag.privacy = r['privacy']
            tag.summary = r['summary']

            tag.save if tag.changed? && tag.valid?
            matched_tag_names << tag.name # This will have the NEW name if it changed
          else # this tag is no longer in the requirement list, demote it
            tag.type = 'wiki'
            tag.save
          end
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

            new_tag.save if new_tag.valid?
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
      
      # Now run the bulk addition of members asynchronously (no poller for now)
      all_user_ids = logs.map{ |log| log.user_id }
      new_group.bulk_add_members(all_user_ids, true)
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

  def add_creator_as_expert
    log = Log.new
    log.badge = self
    log.user = creator
    log.save! 
    # NOTE: This log will automatically be validated (by log.update_stati) 
    # and self-validated (by log.back_validate_if_needed)
  end

  def update_info_sections
    if info_changed?
      linkified_result = linkify_text(info, group, self)
      self.info_sections = linkified_result[:text].split(SECTION_DIVIDER_REGEX)
      self.info_tags = linkified_result[:tags]
      self.info_tags_with_caps = linkified_result[:tags_with_caps]
    end
  end

  def build_badge_image
    if image.nil? || image_frame_changed? || image_icon_changed? || image_color1_changed? \
      || image_color2_changed?
      # First build the image
      badge_image = BadgeMaker.build_image(frame: image_frame, icon: image_icon, 
        color1: image_color1, color2: image_color2)
      unless badge_image.nil?
        self.image = badge_image.to_blob.force_encoding("ISO-8859-1").encode("UTF-8")
        badge_image_wide = BadgeMaker.build_wide_image(badge_image)
        self.image_wide = badge_image_wide.to_blob.force_encoding("ISO-8859-1").encode("UTF-8")
      end

      # Then store the attribution information 
      # Note: The parameters will only be missing for test data, randomization for users will happen
      #       client-side meaning that the potential for missing attribution info below is low.
      self.image_attributions = []
      frame_attribution = BadgeMaker.get_attribution :frames, image_frame
      icon_attribution = BadgeMaker.get_attribution :icons, image_icon
      self.image_attributions << frame_attribution unless frame_attribution.nil?
      self.image_attributions << icon_attribution unless icon_attribution.nil?
    end
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
      elsif !new_group.can_create_badges?
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

end