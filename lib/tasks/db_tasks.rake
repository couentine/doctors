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

end