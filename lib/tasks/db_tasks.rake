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

end