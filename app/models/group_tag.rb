class GroupTag
  include Mongoid::Document
  include Mongoid::Timestamps
  include JSONTemplater
  include AuditHistory
  include StringTools

  # === CONSTANTS === #
  
  MAX_NAME_LENGTH = 21
  MAX_SUMMARY_LENGTH = 300
  GROUP_CACHE_FIELDS = [:_id, :name, :name_with_caps, :summary, :user_magnitude, :badge_magnitude]
  AUDIT_HISTORY_FIELDS = { 
    name_with_caps: { display_name: 'Name', include_values: true },
    summary: { display_name: 'Summary', include_values: true }
  }
  JSON_TEMPLATES = {
    list_item: [:id, :group_id, :name, :name_with_caps, :summary, :user_count, :user_magnitude,
      :badge_count, :badge_magnitude, :total_count, :total_magnitude, :validation_request_count],
    list_with_children: [:id, :group_id, :name, :name_with_caps, :summary, :user_count, 
      :user_magnitude, :badge_count, :badge_magnitude, :total_count, :total_magnitude,
       :validation_request_count, :user_id_strings, :badge_id_strings],
    detail: [:id, :group_id, :name, :name_with_caps, :summary, :user_count, :user_magnitude,
      :badge_count, :badge_magnitude, :total_count, :total_magnitude,
        :validation_request_count, :permissions_text]
  }

  # === INSTANCE VARIABLES === #

  attr_accessor :context # Used to prevent certain callbacks from firing in certain contexts

  # === RELATIONSHIPS === #

  belongs_to :group, inverse_of: :tags
  has_and_belongs_to_many :users # DO NOT EDIT DIRECTLY: Use add_users & remove_users
  has_and_belongs_to_many :badges # DO NOT EDIT DIRECTLY: Use add_badges & remove_badges

  # === FIELDS & VALIDATIONS === #
  
  field :name_with_caps,              type: String # Users should only update this one
  field :name,                        type: String # This one is set automatically
  field :summary,                     type: String
  
  field :user_count,                  type: Integer, default: 0
  field :user_magnitude,              type: Integer, default: 0 # = logarithmic of count

  field :badge_count,                 type: Integer, default: 0
  field :badge_magnitude,             type: Integer, default: 0 # = logarithmic of count

  field :total_count,                 type: Integer, default: 0
  field :total_magnitude,             type: Integer, default: 0 # = lograthimic of count

  field :validation_request_count,    type: Integer, default: 0 # RETIRED - this was initially...
    # ... used to store user validation count total... this will be re-assigned in production...
    # ... via a rake task. then we can delete this altogether
  field :user_validation_request_counts,  
                                      type: Hash, default: {} # key=user_id, value=req_count
  field :user_validation_request_count,
                                      type: Integer, default: 0 # the total from all users
  field :badge_validation_request_counts,
                                      type: Hash, default: {} # key=badge_id, value=req_count
  field :badge_validation_request_count,
                                      type: Integer, default: 0 # the total from all users
  field :user_history,                type: Hash, default: {} #key=user_id,val=hash w/ audit info
  field :badge_history,               type: Hash, default: {} #key=badge_id, val=hash w/ audit info

  validates :group, presence: true
  validates :name, presence: true, length: { within: 2..MAX_NAME_LENGTH }, 
    uniqueness: { scope: :badge }, exclusion: { in: APP_CONFIG['blocked_url_slugs'],
    message: "%{value} is a specially reserved url." }
  validates_format_of :name, :with => /\A[a-z0-9][-_a-z0-9]*[a-z0-9]\Z/
  validates :summary, length: { maximum: MAX_SUMMARY_LENGTH }

  # === CALLBACKS === #

  before_validation :update_validated_fields
  after_validation :copy_name_field_errors
  before_save :update_validation_request_counts_if_needed
  after_save :update_group_cache_if_needed
  before_destroy :remove_from_group_cache_before_destroy

  # === INSTANCE METHODS === #

  # WARNING: This will result in a database query
  def full_path
    "/#{group.url_with_caps}/tags/#{name_with_caps}"
  end

  # WARNING: This will result in a database query
  def full_url
    "#{ENV['root_url'] || 'https://www.badgelist.com'}#{full_path}"
  end

  # Returns stringified version of user_ids
  def user_id_strings
    (user_ids || []).map{ |id| id.to_s }
  end

  # Returns stringified version of badge_ids
  def badge_id_strings
    (badge_ids || []).map{ |id| id.to_s }
  end

  # Returns user-facing explanation of this group tag's privacy settings
  # NOTE: This returns info from the group record (and thus queries the group)
  def permissions_text
    if group.tag_visibility == 'admins'
      return_text = 'only visible to admins' # assignability is obvious
    elsif group.tag_visibility == 'members'
      if group.tag_assignability == 'admins'
        return_text = 'visible to members but only assignable by admins'
      else
        return_text = 'visible to and assignable by all members'
      end
    else
      if group.tag_assignability == 'admins'
        return_text = 'visible to public but only assignable by admins'
      else
        return_text = 'visible to public and assignable by all members'
      end
    end
  end

  # === ADDING AND REMOVING USERS === #

  # Updates user_count, user_magnitude, badge_count and badge_magnitude
  # THE PURPOSE OF MAGNITUDES is to keep from having to update the group tag cache every single
  # time that a user / badge is added or removed. But since the group needs to know which are the 
  # most popular tags, we do need to occasionally update the group. So instead of directly updating 
  # the group cache when the user/badge count changes, we base it off of the 3rd log. So it will 
  # exponentially back off as the tag gets larger.
  def update_counts
    self.user_count = user_ids.count
    
    if user_count == 0
      self.user_magnitude = 0
    elsif user_count == 1
      self.user_magnitude = 1
    else
      self.user_magnitude = Math.log(user_count, 3).ceil
    end

    self.badge_count = badge_ids.count

    if badge_count == 0
      self.badge_magnitude = 0
    elsif badge_count == 1
      self.badge_magnitude = 1
    else
      self.badge_magnitude = Math.log(badge_count, 3).ceil
    end

    self.total_count = user_ids.count + badge_ids.count
    
    if total_count == 0
      self.total_magnitude = 0
    elsif total_count == 1
      self.total_magnitude = 1
    else
      self.total_magnitude = Math.log(total_count, 3).ceil
    end
      
  end
  
  # Adds a list of users and uses the specified user id to set the user history entries
  # If you set async to true then this method will return a poller id
  def add_users(user_ids, current_user_id, async = false)
    if async
      poller = Poller.new
      poller.waiting_message = 'Adding users to group tag...'
      poller.progress = 1
      poller.save
      GroupTag.delay(queue: 'default', retry: false).add_users(user_ids, current_user_id,
        group_tag_id: self.id, poller_id: poller.id)
      poller.id
    else
      GroupTag.add_users(user_ids, current_user_id, group_tag: self)
    end
  end

  # Adds a list of users to this tag (this method will FILTER OUT any non-group-members/admins).
  # current_user_id is important because it's used to store the audit history. It can be skipped if
  # needed, but try not to unless absolutely necessary.
  # Accepts the following options:
  # - group_tag / group_tag_id: Set one of these. Setting group_tag will skip the requery
  # - poller_id: If provided this poller record will be updated with success or failure details
  def self.add_users(user_ids, current_user_id, options = {})
    begin
      poller = Poller.find(options[:poller_id]) rescue nil
      poller.progress = 0 if poller.progress.nil?

      group_tag = options[:group_tag] || GroupTag.find(options[:group_tag_id]) # error if missing
      group = group_tag.group
      current_user_id = current_user_id.to_s # stringify if needed
      
      existing_user_ids = group_tag.user_ids.map{ |id| id.to_s } # stringify
      user_ids = user_ids.map{ |id| id.to_s } # stringify (if needed)
      new_user_ids = user_ids - existing_user_ids
      added_user_count, completed_user_count, completed_progress = 0, 0, 0
      
      # Don't hit the database anymore unless there are users to add
      if !new_user_ids.blank?
        new_users = User.where(:id.in => new_user_ids)
        new_user_count = new_users.count
        new_users.each do |user|
          # Only add them if they are an admin or member of the group
          if user.member_or_admin_of? group
            group_tag.users << user
            user_id_string = user.id.to_s
            
            # Initialize this user's spot in the validation request hash
            group_tag.user_validation_request_counts[user_id_string] \
              = user.group_validation_request_counts[group.id.to_s] || 0
            
            # Set or update this user's audit history
            if group_tag.user_history.has_key? user_id_string
              # This user is being restored
              group_tag.user_history[user_id_string]['status'] = 'restored'
              group_tag.user_history[user_id_string]['restored_at'] = Time.now
              group_tag.user_history[user_id_string]['restored_by'] = current_user_id
            else
              # This user is a new addition
              group_tag.user_history[user_id_string] = {
                'status' => 'added',
                'added_at' => Time.now,
                'added_by' => current_user_id
              }
            end

            added_user_count += 1
          end

          # Now recalculate progress and update the poller if needed
          completed_user_count += 1
          completed_progress = ((completed_user_count.to_d/new_user_count)*100).round
          if completed_progress > poller.progress
            poller.progress = completed_progress
            poller.save
          end
        end

        # WHY TIMELESS? We're saving the standard timestamp fields for changes to name or summary
        group_tag.update_counts
        group_tag.timeless.save if group_tag.changed?
      end

      if poller
        poller.status = 'successful'
        poller.message = "Successfully added #{added_user_count} users to this tag."
        poller.data = { user_ids: user_ids }
        poller.save
      end
    rescue Exception => e
      if poller
        poller.status = 'failed'
        poller.data = { user_ids: user_ids }
        poller.message = 'An error occurred while trying to add users to this tag, ' \
          + "please try again. (Error message: #{e})"
        poller.save
      else
        throw e
      end
    end
  end

  # Removed a list of users and uses the specified user id to set the user history entries
  # If you set async to true then this method will return a poller id
  def remove_users(user_ids, current_user_id, async = false)
    if async
      poller = Poller.new
      poller.save
      GroupTag.delay(queue: 'default', retry: false).remove_users(user_ids, current_user_id,
        group_tag_id: self.id, poller_id: poller.id)
      poller.id
    else
      GroupTag.remove_users(user_ids, current_user_id, group_tag: self)
    end
  end

  # Removes a list of users to this tag if they are present.
  # current_user_id is important because it's used to store the audit history. It can be skipped if
  # needed, but try not to unless absolutely necessary.
  # Accepts the following options:
  # - group_tag / group_tag_id: Set one of these. Setting group_tag will skip the requery
  # - poller_id: If provided this poller record will be updated with success or failure details
  def self.remove_users(user_ids, current_user_id, options = {})
    begin
      poller = Poller.find(options[:poller_id]) rescue nil
      group_tag = options[:group_tag] || GroupTag.find(options[:group_tag_id]) # error if missing
      group = group_tag.group
      current_user_id = current_user_id.to_s # stringify if needed
      
      existing_user_ids = group_tag.user_ids.map{ |id| id.to_s } # stringify
      user_ids = user_ids.map{ |id| id.to_s } # stringify (if needed)
      remove_user_ids = existing_user_ids & user_ids
      removed_user_count = 0
      
      # Don't hit the database anymore unless there are users to remove
      if !remove_user_ids.blank?
        remove_users = User.where(:id.in => remove_user_ids)
        remove_users.each do |user|
          group_tag.users.delete user
          user_id_string = user.id.to_s
          
          # Clear this user's spot in the validation request hash
          group_tag.user_validation_request_counts.delete user_id_string
          
          # Update this user's audit history
          # NOTE: They stay in the history so that we have an audit log of which users were 
          # removed and by whom
          if group_tag.user_history.has_key? user_id_string
            group_tag.user_history[user_id_string]['status'] = 'removed'
            group_tag.user_history[user_id_string]['removed_at'] = Time.now
            group_tag.user_history[user_id_string]['removed_by'] = current_user_id
          end

          removed_user_count += 1
        end

        # WHY TIMELESS? We're saving the standard timestamp fields for changes to name or summary
        group_tag.update_counts
        group_tag.timeless.save if group_tag.changed?
      end

      if poller
        poller.status = 'successful'
        poller.message = "Successfully removed #{removed_user_count} users from this tag."
        poller.data = subscription.to_hash
        poller.save
      end
    rescue Exception => e
      if poller
        poller.status = 'failed'
        poller.message = 'An error occurred while trying to remove users from this tag, ' \
          + "please try again. (Error message: #{e})"
        poller.save
      else
        throw e
      end
    end
  end

  # Call this after a user is deleted to remove them from all group tags which contain them.
  # NOTE: This only removes the user from user_validation_request_counts and user_history.
  #       It doesn't remove them from the users list. (That should happen automatically.)
  def self.clear_deleted_user_from_all(user_id)
    user_id_string = user_id.to_s
    group_tags = GroupTag.where(('user_history.'+user_id_string) => {:$exists => true})
    group_tags.each do |group_tag|
      group_tag.user_validation_request_counts.delete user_id_string
      group_tag.user_history.delete user_id_string
      group_tag.timeless.save if group_tag.changed?
    end

    true
  end

  # === ADDING AND REMOVING BADGES === #
  
  # Adds a list of badges and uses the specified badge id to set the badge history entries
  # If you set async to true then this method will return a poller id
  def add_badges(badge_ids, current_user_id, async = false)
    if async
      poller = Poller.new
      poller.waiting_message = 'Adding badges to group tag...'
      poller.progress = 1
      poller.save
      GroupTag.delay(queue: 'default', retry: false).add_badges(badge_ids, current_user_id,
        group_tag_id: self.id, poller_id: poller.id)
      poller.id
    else
      GroupTag.add_badges(badge_ids, current_user_id, group_tag: self)
    end
  end

  # Adds a list of badges to this tag (this method will FILTER OUT any non-group-members/admins).
  # current_user_id is important because it's used to store the audit history. It can be skipped if
  # needed, but try not to unless absolutely necessary.
  # Accepts the following options:
  # - group_tag / group_tag_id: Set one of these. Setting group_tag will skip the requery
  # - poller_id: If provided this poller record will be updated with success or failure details
  def self.add_badges(badge_ids, current_user_id, options = {})
    begin
      poller = Poller.find(options[:poller_id]) rescue nil
      poller.progress = 0 if poller.progress.nil?

      group_tag = options[:group_tag] || GroupTag.find(options[:group_tag_id]) # error if missing
      group = group_tag.group
      current_user_id = current_user_id.to_s # stringify if needed
      
      existing_badge_ids = group_tag.badge_ids.map{ |id| id.to_s } # stringify
      badge_ids = badge_ids.map{ |id| id.to_s } # stringify (if needed)
      new_badge_ids = badge_ids - existing_badge_ids
      added_badge_count, completed_badge_count, completed_progress = 0, 0, 0
      
      # Don't hit the database anymore unless there are badges to add
      if !new_badge_ids.blank?
        new_badges = Badge.where(:id.in => new_badge_ids)
        new_badge_count = new_badges.count
        new_badges.each do |badge|
          # Only add them if they have not been added before
          if !badge.added_to_group_tag group_tag
            group_tag.badges << badge
            badge_id_string = badge.id.to_s
            
            # Initialize this badge's spot in the validation request hash
            group_tag.badge_validation_request_counts[badge_id_string] \
              = badge.validation_request_count || 0
            
            # Set or update this badge's audit history
            if group_tag.badge_history.has_key? badge_id_string
              # This badge is being restored
              group_tag.badge_history[badge_id_string]['status'] = 'restored'
              group_tag.badge_history[badge_id_string]['restored_at'] = Time.now
              group_tag.badge_history[badge_id_string]['restored_by'] = current_user_id
            else
              # This badge is a new addition
              group_tag.badge_history[badge_id_string] = {
                'status' => 'added',
                'added_at' => Time.now,
                'added_by' => current_user_id
              }
            end

            added_badge_count += 1
          end

          # Now recalculate progress and update the poller if needed
          completed_badge_count += 1
          completed_progress = ((completed_badge_count.to_d/new_badge_count)*100).round
          if completed_progress > poller.progress
            poller.progress = completed_progress
            poller.save
          end
        end

        # WHY TIMELESS? We're saving the standard timestamp fields for changes to name or summary
        group_tag.update_counts
        group_tag.timeless.save if group_tag.changed?
      end

      if poller
        poller.status = 'successful'
        poller.message = "Successfully added #{added_badge_count} badges to this tag."
        poller.data = { badge_ids: badge_ids }
        poller.save
      end
    rescue Exception => e
      if poller
        poller.status = 'failed'
        poller.data = { badge_ids: badge_ids }
        poller.message = 'An error occurred while trying to add badges to this tag, ' \
          + "please try again. (Error message: #{e})"
        poller.save
      else
        throw e
      end
    end
  end

  # Removed a list of badges and uses the specified badge id to set the badge history entries
  # If you set async to true then this method will return a poller id
  def remove_badges(badge_ids, current_user_id, async = false)
    if async
      poller = Poller.new
      poller.save
      GroupTag.delay(queue: 'default', retry: false).remove_badges(badge_ids, current_user_id,
        group_tag_id: self.id, poller_id: poller.id)
      poller.id
    else
      GroupTag.remove_badges(badge_ids, current_user_id, group_tag: self)
    end
  end

  # Removes a list of badges to this tag if they are present.
  # current_user_id is important because it's used to store the audit history. It can be skipped if
  # needed, but try not to unless absolutely necessary.
  # Accepts the following options:
  # - group_tag / group_tag_id: Set one of these. Setting group_tag will skip the requery
  # - poller_id: If provided this poller record will be updated with success or failure details
  def self.remove_badges(badge_ids, current_user_id, options = {})
    begin
      poller = Poller.find(options[:poller_id]) rescue nil
      group_tag = options[:group_tag] || GroupTag.find(options[:group_tag_id]) # error if missing
      group = group_tag.group
      current_user_id = current_user_id.to_s # stringify if needed
      
      existing_badge_ids = group_tag.badge_ids.map{ |id| id.to_s } # stringify
      badge_ids = badge_ids.map{ |id| id.to_s } # stringify (if needed)
      remove_badge_ids = existing_badge_ids & badge_ids
      removed_badge_count = 0
      
      # Don't hit the database anymore unless there are badges to remove
      if !remove_badge_ids.blank?
        remove_badges = Badge.where(:id.in => remove_badge_ids)
        remove_badges.each do |badge|
          group_tag.badges.delete badge
          badge_id_string = badge.id.to_s
          
          # Clear this badge's spot in the validation request hash
          group_tag.badge_validation_request_counts.delete badge_id_string
          
          # Update this badge's audit history
          # NOTE: They stay in the history so that we have an audit log of which badges were 
          # removed and by whom
          if group_tag.badge_history.has_key? badge_id_string
            group_tag.badge_history[badge_id_string]['status'] = 'removed'
            group_tag.badge_history[badge_id_string]['removed_at'] = Time.now
            group_tag.badge_history[badge_id_string]['removed_by'] = current_user_id
          end

          removed_badge_count += 1
        end

        # WHY TIMELESS? We're saving the standard timestamp fields for changes to name or summary
        group_tag.update_counts
        group_tag.timeless.save if group_tag.changed?
      end

      if poller
        poller.status = 'successful'
        poller.message = "Successfully removed #{removed_badge_count} badges from this tag."
        poller.data = subscription.to_hash
        poller.save
      end
    rescue Exception => e
      if poller
        poller.status = 'failed'
        poller.message = 'An error occurred while trying to remove badges from this tag, ' \
          + "please try again. (Error message: #{e})"
        poller.save
      else
        throw e
      end
    end
  end

  # Call this after a badge is deleted to remove them from all group tags which contain them.
  # NOTE: This only removes the badge from badge_validation_request_counts and badge_history.
  #       It doesn't remove them from the badges list. (That should happen automatically.)
  def self.clear_deleted_badge_from_all(badge_id)
    badge_id_string = badge_id.to_s
    group_tags = GroupTag.where(('badge_history.'+badge_id_string) => {:$exists => true})
    group_tags.each do |group_tag|
      group_tag.badge_validation_request_counts.delete badge_id_string
      group_tag.badge_history.delete badge_id_string
      group_tag.timeless.save if group_tag.changed?
    end

    true
  end

  # === GROUP TAG INSTANCE METHODS === #

  # Updates the validation request count for the specified user OR badge
  def update_validation_request_count_for(user_or_badge)
    user = user_or_badge if user_or_badge.class == User
    badge = user_or_badge if user_or_badge.class == Badge
    
    if !user.nil? && user_ids.include?(user.id)
      self.user_validation_request_counts[user.id.to_s] = \
        user.group_validation_request_counts[group_id.to_s] || 0
    elsif !badge.nil? && badge_ids.include?(badge.id)
      self.badge_validation_request_counts[badge.id.to_s] = badge.validation_request_count || 0
    end
  end

  # === GROUP TAG ASYNC METHODS === #

  # None yet

  # === INSTANCE METHODS === #

  def to_param
    name_with_caps
  end

protected

  def update_validated_fields
    # This should make it impossible to ever trigger the max name length validation
    if name_with_caps && (name_with_caps.length > MAX_NAME_LENGTH)
      self.name_with_caps = name_with_caps[0, MAX_NAME_LENGTH]
    end

    # Name is set automatically
    if name_with_caps.nil?
      self.name = nil
    else
      self.name = name_with_caps.downcase
    end

    # This should make it impossible to ever trigger the max summary length validation
    if summary && (summary.length > MAX_SUMMARY_LENGTH)
      self.summary = summary[0, MAX_SUMMARY_LENGTH]
    end
  end

  # Takes any errors from name to name_with_caps (for form display purposes, user can't edit name)
  def copy_name_field_errors
    self.errors[:name_with_caps] = self.errors[:name] if self.errors[:name_with_caps].blank?
  end

  def update_validation_request_counts_if_needed
    if user_validation_request_counts_changed?
      self.user_validation_request_count = \
        (user_validation_request_counts || {}).values.reduce(0, :+)
    end
    if badge_validation_request_counts_changed?
      self.badge_validation_request_count = \
        (badge_validation_request_counts || {}).values.reduce(0, :+)
    end
  end

  # Updates the tags cache on the group object if any of the cached field names change.
  def update_group_cache_if_needed
    # First find the intersection of the fields to watch and the fields that have changed
    cache_field_names = GROUP_CACHE_FIELDS.map{ |field_symbol| field_symbol.to_s }
    changed_cache_field_names = changed & cache_field_names

    unless changed_cache_field_names.blank? # this should always be true when it's a new record
      Group.delay(queue: 'low').update_tags_cache(group_id, self.as_json(only: GROUP_CACHE_FIELDS))
    end
  end

  def remove_from_group_cache_before_destroy
    Group.delay(queue: 'low').remove_tag_from_cache(group_id, id)
  end

end
