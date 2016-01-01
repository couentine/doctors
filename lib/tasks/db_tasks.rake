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

  # One-time migration of users & groups to stripe-based subscriptions & pricing
  task migrate_users_and_groups_to_stripe: :environment do
    user_change_log, group_change_log = [], []

    # User flags / group subscription mappings
    IGNORE_FLAG = 'sm_ignore'
    MANUAL_FLAG = 'sm_manual'
    MANUAL_PLAN = 'free-100m-1'
    STANDARD_FLAG = 'sm_standard'
    STANDARD_PLAN = 'standard-100m-1'
    OG_FLAG = 'sm_og'
    OG_PLAN = 'free-5m-1'

    # List of users who will be dealt with manually
    manual_users = ['hood', 'kucrl', 'hankish', 'benroome', 'miltology', 'kimberly']

    # === STEP 1: MIGRATE USERS === #

    print "Migrating #{User.count} users"
    
    User.each do |user|
      error_item = InfoItem.new
      error_item.type = 'db-task-error'
      error_item.user = user
      error_item.data = { user_id: user.id, username: user.username, email: user.email, 
        name: user.name }

      if user.owned_groups.count == 0
        current_group = :ignore
        user.set_flag IGNORE_FLAG
      else
        begin
          # Create a stripe customer if missing, then retrieve the customer object
          user.create_stripe_customer if user.stripe_customer_id.blank?  
          customer = Stripe::Customer.retrieve(user.stripe_customer_id)

          # Next determine when they created their first group
          first_group_create_date = user.owned_groups.asc(:created_at).first.created_at
          pricing_published_date = '2015-04-22'.to_time

          # Now determine this user's group and set flags
          if manual_users.include? user.username
            current_group = :manual
            user.set_flag MANUAL_FLAG
          elsif first_group_create_date < pricing_published_date
            current_group = :og
            user.set_flag OG_FLAG
          else
            current_group = :standard
            user.set_flag STANDARD_FLAG
          end

          # Add the og coupon to manual and og groups
          if [:manual, :og].include? current_group
            begin
              customer.coupon = 'og-perma-50'
              customer.save
              user.set_flag User::HALF_OFF_FLAG
            rescue Exception => e
              error_item.name = 'Error Adding Coupon (migrate_users_and_groups_to_stripe)'
              error_item.data[:error] = e.to_s
            end
          end
        rescue Exception => e
          error_item.name = 'Error Creating Stripe Customer (migrate_users_and_groups_to_stripe)'
          error_item.data[:error] = e.to_s
        end
      end

      error_item.data[:flags] = user.flags
      user_change_log << error_item.data
      
      if error_item.name
        print '!'
        error_item.save
      else
        print "."
      end

      user.save if user.changed?
    end

    # Save results to info item
    item = InfoItem.new
    item.type = 'db-task-result'
    item.name = 'Summary of User Changes (migrate_users_and_groups_to_stripe)'
    item.data = { user_change_log: user_change_log }
    item.save

    puts " >> Done."

    # === STEP 2: MIGRATE GROUPS === #

    print "Migrating #{Group.where(type: 'private').count} private groups"
    
    Group.where(type: 'private').each do |group|
      error_item = InfoItem.new
      error_item.type = 'db-task-error'
      error_item.group = group
      error_item.data = { name: group.name, url: group.url, owner_id: group.owner_id }

      begin
        owner = group.owner

        error_item[:owner_email] = owner.email
        error_item[:owner_name] = owner.name
        error_item[:owner_username] = owner.username

        if group.subscription_plan
          print "-"
        else
          if owner.has_flag? MANUAL_FLAG
            group.subscription_plan = MANUAL_PLAN
            trial_end = nil
          elsif owner.has_flag? OG_FLAG
            group.subscription_plan = OG_PLAN
            trial_end = nil
          elsif owner.has_flag? STANDARD_FLAG
            group.subscription_plan = STANDARD_PLAN
            trial_end = [(group.created_at + 2.weeks).to_i, 4.days.from_now.to_i].max
          else
            throw 'The group owner didn\'t have a migration flag!'
          end

          # Create the subscription (syncronously)
          group.stripe_subscription_status = 'trialing'
          Group.create_stripe_subscription(group: group, trial_end: trial_end)
        end
      rescue Exception => e
        error_item.name = 'Error Migrating Group (migrate_users_and_groups_to_stripe)'
        error_item.data[:error] = e.to_s
      end

      error_item.data[:subscription_plan] = group.subscription_plan
      error_item.data[:stripe_subscription_id] = group.stripe_subscription_id
      error_item.data[:stripe_subscription_status] = group.stripe_subscription_status
      error_item.data[:subscription_end_date] = group.subscription_end_date
      group_change_log << error_item.data

      if error_item.name
        print '!'
        error_item.save
      else
        print "."
      end
    end

    # Save results to info item
    item = InfoItem.new
    item.type = 'db-task-result'
    item.name = 'Summary of Group Changes (migrate_users_and_groups_to_stripe)'
    item.data = { group_change_log: group_change_log }
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
      if badge.group.private?
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
      User.update_log_user_fields user.id
      print "."
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

end