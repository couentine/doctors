require "#{Rails.root}/lib/modules/string_tools"
include StringTools

namespace :db do
  
  desc "Rebuild the html and tags for the wikis on badges, logs and entries"
  task relinkify_all: :environment do
    
    print "Updating #{Badge.count} badges"
    Badge.each do |badge|
      linkified_result = linkify_text(badge.info, badge.group, badge)
      badge.info_sections = linkified_result[:text].split(SECTION_DIVIDER_REGEX)
      badge.tags = linkified_result[:tags]
      badge.tags_with_caps = linkified_result[:tags_with_caps]
      badge.timeless.save
      print "."
    end
    puts " >> Done."

    print "Updating #{Log.count} logs"
    Log.each do |log|
      unless log.badge.nil?
        linkified_result = linkify_text(log.wiki, log.badge.group, log.badge)
        log.wiki_sections = linkified_result[:text].split(SECTION_DIVIDER_REGEX)
        log.tags = linkified_result[:tags]
        log.tags_with_caps = linkified_result[:tags_with_caps]
        log.timeless.save
        print "."
      end
    end
    puts " >> Done."

    print "Updating #{Entry.count} entries"
    Entry.each do |entry|
      unless entry.log.badge.nil?
        linkified_result = linkify_text(entry.body, entry.log.badge.group, entry.log.badge)
        entry.body_sections = linkified_result[:text].split(SECTION_DIVIDER_REGEX)
        entry.tags = linkified_result[:tags]
        entry.tags_with_caps = linkified_result[:tags_with_caps]
        entry.timeless.save
        print "."
      end
    end
    puts " >> Done."

  end  

  task set_thresholds: :environment do
    print "Updating #{Group.count} groups"
    Group.each do |group|
      if group.validation_threshold > 1
        group.validation_threshold = 1
        group.timeless.save
      end
      print "."
    end
    puts " >> Done."
  end

  task update_tag_fields: :environment do
    print "Updating #{Tag.count} tags"
    Tag.each do |tag|
      if tag.display_name.blank?
        tag.display_name = tag.name_with_caps.gsub(/[^A-Za-z0-9]/, ' ').gsub(/ {2,}/, ' ')
      end
      tag.editability = 'learners' if tag.editability.blank?
      tag.timeless.save if tag.changed?
      print "."
    end
    puts " >> Done."
  end

  task update_badge_fields: :environment do
    print "Updating #{Badge.count} badges"
    Badge.each do |badge|
      badge.word_for_expert = 'expert' if badge.word_for_expert.blank?
      badge.word_for_learner = 'learner' if badge.word_for_learner.blank?
      badge.progress_tracking_enabled = true
      badge.timeless.save if badge.changed?
      print "."
    end
    puts " >> Done."
  end

  task update_identity_hashes: :environment do
    print "Updating #{User.count} users"
    User.each do |user|
      user.manually_update_identity_hash
      user.timeless.save if user.changed?
      print "."
    end
    puts " >> Done."
  end

  task list_dupe_logs: :environment do
    puts "Listing dupe logs..."
    log_to_keep, kept_is_issued, kept_entry_count = nil, nil, nil
    
    Badge.each do |badge|
      user_log_map = {} # maps from user to list of logs
      
      badge.logs.each do |log|
        if user_log_map.include? log.user
          user_log_map[log.user] << log
        else
          user_log_map[log.user] = [log]
        end
      end
      
      user_log_map.each do |user, logs|
        if logs.count > 1
          log_to_keep, kept_is_issued, kept_entry_count = nil, false, 0
          
          logs.each do |log|
            keep_me = false

            if log_to_keep.nil?
              keep_me = true
            elsif kept_is_issued # then we can only keep other issued logs with higher counts
              keep_me = true if !log.date_issued.nil? && (log.entries.count > kept_entry_count)
            elsif !log.date_issued.nil? || (log.entries.count > kept_entry_count)
              keep_me = true
            end

            if keep_me
              log_to_keep = log
              kept_is_issued = !log.date_issued.nil?
              kept_entry_count = log.entries.count
            end
          end
          
          logs.each do |log|
            print "#{badge.group.url}/#{badge.url}/#{user.username}/#{log.id} = " \
              + "#{log.entries.count}, #{(log.date_issued.nil?) ? 'learner' : 'expert'} >> "
            if log_to_keep == log
              puts "KEEP"
            else
              puts "DELETE"
            end
          end
        end
      end
    end

    puts " >> Done."
  end

  task delete_dupe_logs: :environment do
    puts "Deleting duplicate logs..."
    log_to_keep, kept_is_issued, kept_entry_count = nil, nil, nil
    
    Badge.each do |badge|
      user_log_map = {} # maps from user to list of logs
      
      badge.logs.each do |log|
        if user_log_map.include? log.user
          user_log_map[log.user] << log
        else
          user_log_map[log.user] = [log]
        end
      end
      
      user_log_map.each do |user, logs|
        if logs.count > 1
          log_to_keep, kept_is_issued, kept_entry_count = nil, false, 0
          
          logs.each do |log|
            keep_me = false

            if log_to_keep.nil?
              keep_me = true
            elsif kept_is_issued # then we can only keep other issued logs with higher counts
              keep_me = true if !log.date_issued.nil? && (log.entries.count > kept_entry_count)
            elsif !log.date_issued.nil? || (log.entries.count > kept_entry_count)
              keep_me = true
            end

            if keep_me
              log_to_keep = log
              kept_is_issued = !log.date_issued.nil?
              kept_entry_count = log.entries.count
            end
          end
          
          logs.each do |log|
            print "#{badge.group.url}/#{badge.url}/#{user.username}/#{log.id} = " \
              + "#{log.entries.count}, #{(log.date_issued.nil?) ? 'learner' : 'expert'} >> "
            if log_to_keep == log
              puts "KEEPING"
            else
              if log.delete
                puts "DELETED"
              else
                puts "ERROR DELETING"
              end
            end
          end
        end
      end
    end

    puts " >> Done."
  end

  task overwrite_user_active_months: :environment do
    print "Updating #{User.count} users"
    
    User.each do |user|
      user.active_months = [] if user.active_months.nil?
      
      user.page_views.each do |key, value|
        value["dates"].each do |view_time|
          month_key = view_time.to_s(:year_month)
          user.active_months << month_key unless user.active_months.include?(month_key)
          user.last_active_at = view_time if user.last_active_at.nil? \
            || (view_time > user.last_active_at)
        end
      end
      
      if user.changed?
        user.active_months.sort!
        user.timeless.save
      end
      print "."
    end

    puts " >> Done."
  end

  # WARNING >> The badge topics field has been retired and replaced by the requirements method.
  task backpopulate_parent_tags: :environment do
    print "Examining #{Entry.count} entries"
    
    Badge.each do |badge|
      # First extract the topics from the badge
      topic_list = []
      topic_list_caps_map = {}
      badge.topics.each do |t|
        topic_list << t['tag_name']
        topic_list_caps_map[t['tag_name']] = t['tag_name_with_caps']
      end unless badge.topics.empty?

      # Now loop through all entries in the badge and make sure they all have parent tags
      badge.logs.each do |log|
        log.entries.each do |entry|
          if entry.parent_tag.blank? && !entry.tags.empty?
            # The tags in the summary are processed last so go through in reverse
            entry.tags.reverse.each do |tag|
              if topic_list.include? tag
                # Basically we just pick the first tag to also be found in the badge topic list
                entry.parent_tag = topic_list_caps_map[tag]
                break
              end
            end

            # If none of the tags were in the badge topic list then just pick the last one
            entry.parent_tag = entry.tags_with_caps.last if entry.parent_tag.blank?
          end
          
          entry.timeless.save if entry.changed?
          print "."
        end
      end

    end

    puts " >> Done."
  end

  # Runs through and makes sure all tags have the appropriate metadata
  task fix_badge_tags: :environment do
    print "Updating #{Badge.count} badges"

    Badge.each do |badge|
      # First build a map of current tags
      badge_tags = {}
      badge.tags.each { |tag| badge_tags[tag.name] = tag }

      # Now run through the topic list and process name changes while building new requirement list
      new_requirement_name_list = []
      sort_index = 0
      badge.topic_list_text.split(/\r?\n|,/).each do |tag_display_name|
        unless tag_display_name.blank?
          sort_index += 1
          tag_name_with_caps = tagify_string tag_display_name
          tag_name = tag_name_with_caps.downcase
          new_requirement_name_list << tag_name
          
          if badge_tags.has_key? tag_name
            badge_tags[tag_name].type = 'requirement'
            badge_tags[tag_name].sort_order = sort_index
            badge_tags[tag_name].display_name = tag_display_name
            badge_tags[tag_name].name_with_caps = tag_name_with_caps
            badge_tags[tag_name].timeless.save if badge_tags[tag_name].changed?
          else
            new_tag = Tag.new()
            new_tag.badge = badge
            new_tag.type = 'requirement'
            new_tag.sort_order = sort_index
            new_tag.name = tag_name
            new_tag.display_name = tag_display_name
            new_tag.name_with_caps = tag_name_with_caps
            new_tag.timeless.save
          end
        end
      end unless badge.topic_list_text.blank?

      # Finally run through and make sure that any extra tags have a value for type
      badge.tags.each do |tag|
        unless new_requirement_name_list.include? tag.name
          tag.type = 'wiki'
          tag.timeless.save if tag.changed?
        end
      end

      print "."
    end

    puts " >> Done."
  end

  # Updates linkified summaries on any entries which are missing them
  task backpopulate_linkified_summaries: :environment do
    print "Examining #{Entry.count} entries"
    
    Entry.each do |entry|
      if entry.summary && entry.linkified_summary.blank? && entry.log && entry.log.badge
        summary_result = linkify_text(entry.summary, entry.log.badge.group, entry.log.badge)
        entry.linkified_summary = summary_result[:text]
        body_result = linkify_text(entry.body, entry.log.badge.group, entry.log.badge)
        entry.tags = [body_result[:tags], summary_result[:tags]].flatten.uniq
        entry.tags_with_caps = [body_result[:tags_with_caps], summary_result[:tags_with_caps]]\
          .flatten.uniq
        
        entry.timeless.save if entry.changed?
      end

      print "."
    end

    puts " >> Done."
  end

  # Populates wide badge images for badges missing them 
  # (and in the case of uploaded images for all of them)
  task backpopulate_wide_badge_images: :environment do
    print "Updating #{Badge.count} badges"

    Badge.each do |badge|
      if (badge.image_mode == 'upload') && badge.uploaded_image && badge.uploaded_image.file \
          && badge.uploaded_image.file.content_type
        badge.uploaded_image.recreate_versions!
      elsif !badge.image.nil? && badge.image_wide.nil?
        badge_image = MiniMagick::Image.read(badge.image.encode('ISO-8859-1'))
        badge_image_wide = BadgeMaker.build_wide_image(badge_image)
        badge.image_wide = badge_image_wide.to_blob.force_encoding("ISO-8859-1").encode("UTF-8")
      end

      badge.timeless.save if badge.changed?
      print "."
    end

    puts " >> Done."
  end

  task backpopulate_group_owners: :environment do
    print "Updating #{Group.count} groups"
    Group.each do |group|
      if group.owner.nil? && group.creator
        group.owner = group.creator
        group.admins << group.owner unless group.admin_ids.include? group.owner_id
        group.timeless.save(validate: false)
      end
      print "."
    end
    puts " >> Done."
  end

  task update_group_counts: :environment do
    print "Updating #{Group.count} groups"
    Group.each do |group|
      group.total_user_count = group.member_ids.count + group.admin_ids.count
      group.admin_count = group.admin_ids.count
      group.member_count = group.member_ids.count
      group.timeless.save(validate: false)

      print "."
    end
    puts " >> Done."
  end

  # Randomly reassigns everyone's user accounts to various test emails (and overwrites passwords)
  task staging_only_change_all_user_accounts: :environment do
    test_gmails = ['ryan.hank', 'benroome', 'quemalex']
    change_log = []

    print "Updating #{User.count} users"
    User.each do |user|
      unless user.admin?
        begin
          change_log_item = { id: user.id, name: user.name, original_email: user.email }
          user.email = "#{test_gmails.sample}+#{user.username}@gmail.com"
          user.password = 'Password123'
          user.skip_reconfirmation!
          user.timeless.save
          print "."

          change_log_item[:new_email] = user.email
          change_log << change_log_item
        rescue
          print "!"
        end
      end
    end

    # Save results to info item
    item = InfoItem.new
    item.type = 'db-task-result'
    item.name = 'Summary of Changes (staging_only_change_all_user_emails)'
    item.data = { change_log: change_log }
    item.save

    puts " >> Done."
  end

  task migrate_user_activity_metrics: :environment do
    print "Updating #{User.count} users"
    
    User.each do |user|
      user.last_active = user.last_active_at.to_date if user.last_active_at
      user.last_active_at = nil
      user.page_views = {}
      user.active_months = []
      user.timeless.save
      
      print "."
    end

    puts " >> Done."
  end

  task clear_group_activity_metrics: :environment do
    print "Updating #{Group.count} groups"
    
    Group.each do |group|
      group.active_user_count = nil
      group.monthly_active_users = {}
      group.timeless.save
      
      print "."
    end

    puts " >> Done."
  end

  task migrate_badge_images_to_s3: :environment do
    print "Updating #{Badge.count} badges"

    Badge.each do |badge|
      begin
        # First build the designed image
        badge.rebuild_designed_image

        # Then move the uploaded image from GridFS to S3 (if present)
        if badge.uploaded_image?
          badge.custom_image = badge.uploaded_image.file
          badge.timeless.save!
        end

        print "."
      rescue
        print "!"
      end
    end
    
    puts " >> Done."
  end

  task clear_old_badge_images: :environment do
    print "Updating #{Badge.count} badges"

    Badge.each do |badge|
      begin
        badge.remove_uploaded_image! if badge.uploaded_image?
        badge.image = nil
        badge.image_wide = nil

        badge.timeless.save!
        print "."
      rescue
        print "!"
      end
    end
    
    puts " >> Done."
  end

  task populate_badge_image_keys: :environment do
    print "Updating #{Badge.count} badges"

    Badge.each do |badge|
      begin
        if badge.custom_image? && badge.custom_image_key.blank?
          badge.custom_image_key = Badge::IMAGE_KEY_IGNORE
          badge.timeless.save!
        end
        print "."
      rescue
        print "!"
      end
    end
    
    puts " >> Done."
  end

  # Goes back and sets send badge notifications to false for badges without requirements
  task fix_badge_notification_settings: :environment do
    badges = Badge.where(progress_tracking_enabled: false)

    print "Updating #{badges.count} badges"

    badges.each do |badge|
      begin
        if !badge.has_requirements?
          badge.send_validation_request_emails = false
          badge.timeless.save! if badge.changed?
          print "*"
        else
          print "."
        end
      rescue
        print "!"
      end
    end
    
    puts " >> Done."
  end

  task overwrite_private_group_visibility_settings: :environment do
    print "Updating #{Group.where(type: 'private').count} private groups"
    
    Group.where(type: 'private').each do |group|
      group.member_visibility = 'private'
      group.admin_visibility = 'private'
      group.timeless.save
      
      print "."
    end

    puts " >> Done."
  end

  task overwrite_badge_visibility_settings: :environment do
    print "Updating #{Badge.count} badges"
    
    Badge.each do |badge|
      if badge.group.has?(:privacy)
        badge.visibility = 'private'
      else
        badge.visibility = 'public'
      end
      badge.timeless.save
      
      print "."
    end

    puts " >> Done."
  end

  # NOTE: This is OK to run periodically in production.
  task update_log_user_caches: :environment do
    print "Updating logs for #{User.count} users"
    
    User.each do |user|
      begin
        User.update_log_user_fields user.id
        print "."
      rescue
        print "!"
      end
    end

    puts " >> Done."
  end

  task backpopulate_postmark_bounce_history: :environment do
    print "Querying postmark for all email bounces"

    all_bounces = []
    postmark_client = Postmark::ApiClient.new(ENV['POSTMARK_API_KEY'])
    postmark_client.bounces.each do |bounce|
      all_bounces << bounce
      print "."
    end

    puts " >> Done."

    all_bounces.reverse! # We want them ordered from oldest to newest (which is backwards)

    print "Processing #{all_bounces.count} queried bounces"
    all_bounces.each do |bounce|
      bounced_at = DateTime.parse(bounce[:bounced_at]) rescue Time.now
      User.track_bounce(bounce[:email], bounce[:inactive], bounced_at, bounce[:id])
      print "."
    end

    puts " >> Done."
  end

  task update_user_badge_lists: :environment do
    print "Updating all users and badges linked to #{Log.count} logs"
    
    Log.each do |log|
      Log.update_user_badge_lists(log.id) if log.badge && log.user
      print "."
    end

    puts " >> Done."
  end

  # NOTE: This is OK to run periodically in production.
  task update_json_clones: :environment do
    print "Updating all json clone info for #{Group.count} groups, #{Badge.count} badges " \
      + "and #{Tag.count} tags"
    group_index = 1
    
    Group.each do |group|
      print ", #{group_index}:"

      group.badges.each do |badge|
        badge.update_json_clone_badge_fields(false)
        group.update_badge_cache badge.json_clone

        badge.tags.each do |tag|
          tag.update_json_clone
          tag.context = 'badge_async' # prevent the badge update callback from firing
          tag.timeless.save
          print "-"

          badge.update_json_clone_tag tag.json_clone
        end

        # One-time fix: We need to filter out any items with ids that are not stringified
        # Refer to issue #374 for an explanation. We should be able to delete this once it is run,
        # though it shouldn't really hurt anything.
        if badge.json_clone && badge.json_clone['pages']
          badge.json_clone['pages'] = badge.json_clone['pages'].reject do |tag_item|
            tag_item['_id'].class == BSON::ObjectId
          end
        end

        badge.timeless.save
        print "."
      end

      group.timeless.save
      group_index += 1
    end

    puts " >> Done."
  end

  task overwrite_badge_copyability_on_private_groups: :environment do
    print "Updating #{Group.where(type: 'private').count} private groups"
    
    Group.where(type: 'private').each do |group|
      group.badge_copyability = 'admins'
      group.timeless.save

      print "."
    end

    puts " >> Done."
  end

  task backpopulate_group_avatars: :environment do
    print "Updating #{Group.count} groups"
    
    # Run through them backwards (to minimize user impact since this is a somewhat slow process)
    Group.desc(:updated_at).each do |group|
      unless group.image_url.blank?
        group.remote_avatar_url = group.image_url
        group.timeless.save
      end

      print "."
    end

    puts " >> Done."
  end

  task backpopulate_user_avatars: :environment do
    print "Updating #{User.count} users"
    
    # Run through them backwards (to minimize user impact since this is a somewhat slow process)
    User.desc(:updated_at).each do |user|
      user.remote_avatar_url = user.gravatar_url
      user.timeless.save

      print "."
    end

    puts " >> Done."
  end

  # NOTE: This is OK to run periodically in production.
  task update_badge_group_caches: :environment do
    print "Updating badge group caches for #{Group.count} groups"
    
    Group.each do |group|
      begin
        Group.update_child_badge_fields group.id
        print "."
      rescue
        print "!"
      end
    end

    puts " >> Done."
  end

  task populate_blank_group_avatars: :environment do
    print "Updating #{Group.where(image_url: nil).count} blank avatar groups"
    
    # Run through them backwards
    Group.where(image_url: nil).desc(:updated_at).each do |group|
      if group.avatar?
        print "!"
      else
        group.remote_avatar_url = \
    'https://badgelist.s3.amazonaws.com/u/group/56c3b38be87b738c15000073/default-group-avatar.png'
        group.timeless.save
        print "."
      end
    end

    puts " >> Done."
  end

  task update_log_validation_caches: :environment do
    print "Updating #{Log.count} logs"
    
    Log.each do |log|
      log.validations.each do |entry|
        if entry.creator_id
          log.validations_cache[entry.creator_id.to_s] = {
            'entry_id' => entry.id,
            'log_validated' => entry.log_validated,
            'summary' => entry.summary,
            'body' => entry.body
          }
        end
      end

      log.timeless.save if log.changed?
      print "."
    end

    puts " >> Done."
  end

  # OK to run in production if things get messed up in the database
  task update_badge_validation_request_counts: :environment do
    print "Updating #{Badge.count} badges"

    Badge.each do |badge|
      badge.update_validation_request_count

      if badge.timeless.save
        print "."
      else
        print "!#{badge.id}"
      end
    end
    
    puts " >> Done."
  end

  # OK to run in production if things get messed up in the database
  task update_user_validation_request_fields: :environment do
    print "Updating #{User.count} users"
    
    # Run through them backwards
    User.each do |user|
      # First buid the group validation count hash
      Group.where(:id.in => (user.admin_of_ids + user.member_of_ids).uniq).each do |group|
        user.update_validation_request_count_for group
      end

      # Then update the requested badge ids
      user.requested_badge_ids = user.logs.where(detached_log: false, 
        validation_status: 'requested').map{ |log| log.badge_id }

      if user.timeless.save
        print "."
      else
        print "!#{user.username_with_caps}"
      end
    end

    puts " >> Done."
  end

  task set_log_show_on_badge: :environment do
    print "Updating show on badge setting for #{Log.count} logs"
    
    Log.each do |log|
      log.show_on_badge = true
      if log.timeless.save
        print "."
      else
        print "!"
      end
    end

    puts " >> Done."
  end

  task initialize_all_group_settings: :environment do
    print "Resetting all group settings to defaults for #{User.count} users"
    
    User.each do |user|
      (user.admin_of_ids + user.member_of_ids).each do |group_id|
        user.initialize_group_settings_for group_id
      end

      if user.timeless.save
        print "."
      else
        print "!"
      end
    end

    puts " >> Done."
  end

  # OK to run in production if things get messed up in the database
  # Refreshes the values of expert_user_ids, learner_user_ids, all_user_ids
  task fix_badge_user_caches: :environment do
    print "Updating #{Badge.count} badges"

    Badge.each do |badge|
      badge.expert_user_ids = badge.expert_logs.map{ |log| log.user_id }
      badge.learner_user_ids = badge.learner_logs.map{ |log| log.user_id }
      badge.all_user_ids = badge.logs(detached_log: false).map{ |log| log.user_id }

      if badge.changed?
        if badge.timeless.save
          print "."
        else
          print "!#{badge.id}"
        end
      else
        print '-'
      end
    end
    
    puts " >> Done."
  end

  # Run this is production any time you update the subscription FEATURES for existing plans
  # in config.yml. This method will call the refresh_subscription_features method on all groups
  # with subscription plans.
  # This does *not* override manually granted features (those are stored in separate booleans).
  task refresh_group_subscription_features: :environment do
    print "Updating #{Group.where(:subscription_plan.ne => nil).count} groups"

    Group.where(:subscription_plan.ne => nil).each do |group|
      group.refresh_subscription_features

      if group.changed?
        if group.timeless.save
          print "."
        else
          print "!#{group.url_with_caps}"
        end
      else
        print '-'
      end
    end
    
    puts " >> Done."
  end

  # ONE TIME MIGRATION: Retiring the previous values of group type
  task migrate_group_types: :environment do
    print "Updating #{Group.count} groups"

    Group.each do |group|
      if group.type == 'open'
        group.type = 'free'
      elsif group.type == 'closed'
        group.type = 'free'
        group.joinability = 'closed'
      elsif group.type == 'private'
        group.type = 'paid'
      end

      if group.changed?
        if group.timeless.save
          print "."
        else
          print "!#{group.url_with_caps}"
        end
      else
        print '-'
      end
    end
    
    puts " >> Done."
  end

  # One-time task. Finds all image entries which are stuck at processing and marks them as error state.
  task fix_images_stuck_in_processing: :environment do
    entry_criteria = Entry.where(format: 'image', processing_uploaded_image: true, :created_at.lt => 5.minutes.ago)
    print "Updating #{entry_criteria.count} entries"

    entry_criteria.each do |entry|
      entry.processing_uploaded_image = false
      entry.image_processing_error = true

      if entry.changed?
        if entry.timeless.save
          print "."
        else
          print "!#{entry.id}"
        end
      else
        print '-'
      end
    end
    
    puts " >> Done."
  end

  # This is safe to run in production. It just instantiates users and checks to see if they have changed (usually due to a new field 
  # which has been created with a default value) and then timeless saves if so.
  task save_all_users: :environment do
    print "Saving all users if needed (#{User.count} users total)"
    
    User.each do |user|
      if user.changed?
        if user.timeless.save
          print "."
        else
          print "!"
        end
      else
        print "-"
      end
    end

    puts " >> Done."
  end

  # This creates a proxy user for any groups missing proxy users. Safe to run in production, but shouldn't be needed unless something goes
  # wrong and a proxy user errors out on save. Or is somehow deleted. (Not sure how that would be possible.)
  task create_missing_group_proxy_users: :environment do
    print "Checking for groups with missing proxy users (#{Group.count} groups total)"

    Group.each do |group|
      if group.proxy_user.blank?
        group.proxy_user = User.new
        group.proxy_user.type = 'group'

        group.proxy_user.skip_confirmation!
        group.proxy_user.skip_reconfirmation!

        if group.proxy_user.save
          print "."
        else
          print "!"
        end
      else
        print "-"
      end
    end
    
    puts " >> Done."
  end

  # This looks for any users which are missing from intercom and creates them. It shouldn't normally be necessary to run this.
  # NOTE: It only checks for users who have been active in the last 45 days
  task backpopulate_intercom_users: :environment do
    user_criteria = User.where(:last_active.gte => 45.days.ago)
    intercom = Intercom::Client.new(token: ENV['INTERCOM_TOKEN'])

    puts "===CHECKING FOR 45 DAY ACTIVE USERS WHO ARE MISSING FROM INTERCOM==="
    puts "===> ACTIVE USER COUNT: #{user_criteria.count}"
    print "===> Running..."

    user_criteria.each do |user|
      intercom_user = intercom.users.find(user_id: user.id) rescue nil

      if intercom_user.blank?
        intercom_user = intercom.users.create(email: user.email, name: user.name, user_id: user.id.to_s, signed_up_at: user.created_at.to_i)
        print '+'
      else
        print '.'
      end
    end
    
    puts " >> Done."
  end

  # OK to run in production
  task update_badge_user_counts: :environment do
    print "Updating #{Badge.count} badges"

    Badge.each do |badge|
      badge.learner_count = badge.learner_user_ids.count
      badge.expert_count = badge.expert_user_ids.count

      if !badge.changed?
        print "-"
      elsif badge.timeless.save
        print "."
      else
        print "!#{badge.id.to_s}"
      end
    end
    
    puts " >> Done."
  end

  # OK to run in production
  task update_group_badge_counts: :environment do
    print "Updating #{Group.count} groups"

    Group.each do |group|
      badge_counts = group.badges_cache.values.reduce({}) do |counts, badge_item|
        counts[badge_item['visibility']] = (counts[badge_item['visibility']] || 0) + 1
        counts
      end

      group.public_badge_count = badge_counts['public'] || 0
      group.private_badge_count = badge_counts['private'] || 0
      group.hidden_badge_count = badge_counts['hidden'] || 0
      group.all_badge_count = group.badges_cache.count

      if !group.changed?
        print "-"
      elsif group.timeless.save
        print "."
      else
        print "!#{group.id.to_s}"
      end
    end
    
    puts " >> Done."
  end

  # OK to run in production... doesn't modify database, just spits out a list of group validation errors
  task list_invalid_groups: :environment do
    puts "#=== FINDING ALL GROUP VALIDATION ERRORS ===#"
    puts ''

    invalid_group_count = 0
    
    Group.each do |group|
      if !group.valid?
        puts "#{group.url_with_caps} (#{group.id.to_s}) => #{group.errors.full_messages.join('. ')}."
        invalid_group_count += 1
      end
    end

    puts ''
    puts "#=== COMPLETE ===#"
    puts "#===> Invalid Group Count = #{invalid_group_count}"
  end

  # OK to run in production... doesn't modify database, just spits out a list of badge validation errors
  task list_invalid_badges: :environment do
    puts "#=== FINDING ALL BADGE VALIDATION ERRORS ===#"
    puts ''

    invalid_badge_count = 0
    
    Badge.each do |badge|
      if !badge.valid?
        puts "#{badge.record_path} (#{badge.id.to_s}) => #{badge.errors.full_messages.join('. ')}."
        invalid_badge_count += 1
      end
    end

    puts ''
    puts "#=== COMPLETE ===#"
    puts "#===> Invalid Badge Count = #{invalid_badge_count}"
  end

end