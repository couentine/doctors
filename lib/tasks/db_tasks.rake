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
      tag.display_name = tag.name_with_caps.gsub(/[^A-Za-z0-9]/, ' ').gsub(/ {2,}/, ' ') if tag.display_name.blank?
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
            print "#{badge.group.url}/#{badge.url}/#{user.username}/#{log.id} = #{log.entries.count}, #{(log.date_issued.nil?) ? 'learner' : 'expert'} >> "
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
            print "#{badge.group.url}/#{badge.url}/#{user.username}/#{log.id} = #{log.entries.count}, #{(log.date_issued.nil?) ? 'learner' : 'expert'} >> "
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
  task backpopulate_wide_badge_images: :environment do
    print "Updating #{Badge.count} badges"

    Badge.each do |badge|
      if (badge.image_mode == 'upload') && badge.uploaded_image && badge.uploaded_image.file \
          && badge.uploaded_image.file.content_type \
          && !badge.uploaded_image.version_exists?('wide')
        # FIXME
        # badge_image = MiniMagick::Image.read(badge.uploaded_image.wide.read)
        # badge_image_wide = BadgeMaker.build_wide_image(badge_image)
        # badge.image_wide = badge_image_wide.to_blob.force_encoding("ISO-8859-1").encode("UTF-8")
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

end