namespace :db do
  desc "Fill database with sample data"
  task populate: :environment do
    puts "Loading config...\n\n"
    @example_data = YAML.load_file("#{Rails.root}/config/example_data.yml")
    puts "Making users..."
    make_users
    puts "\nMaking everything else..."
    make_everything_else
    puts "\nDONE!"
  end

  desc "Clear all previously created sample data from database"
  task clear_sample_data: :environment do
    print "Deleting #{User.where(:flags => 'sample_data').count} records from User..."
    User.where(:flags => 'sample_data').destroy_all
    puts " >> Done."

    print "Deleting #{Badge.where(:flags => 'sample_data').count} records from Badge..."
    Badge.where(:flags => 'sample_data').destroy_all
    puts " >> Done."

    print "Deleting #{Group.where(:flags => 'sample_data').count} records from Group..."
    Group.where(:flags => 'sample_data').destroy_all
    puts " >> Done."

    print "Deleting #{Log.where(:flags => 'sample_data').count} records from Log..."
    Log.where(:flags => 'sample_data').destroy_all
    puts " >> Done."

    print "Deleting #{Entry.where(:flags => 'sample_data').count} records from Entry..."
    Entry.where(:flags => 'sample_data').destroy_all
    puts " >> Done."
  end

  def make_users
    # first define the acceptable time range for account creation (start_time..end_time)
    user_start_time = Time.now - 1.year
    user_end_time = user_start_time + 1.month

    # make admins
    1.times do |n|
      name = Faker::Name.name
      username = "zadmin#{n+1}"
      email = "admin#{n+1}@hankish.com"
      password = "password"
      flags = ['sample_data']
      joined_at = rand(user_start_time..user_end_time)
      user = User.new(:name => name,
                   :username => username,
                   :email => email,
                   :password => password)
      user.flags = flags
      user.created_at = joined_at
      user.updated_at = joined_at + 1.hour
      user.skip_confirmation!
      user.timeless.save! if user.valid?
    end
    puts ">> 1 admin created."

    # make learners
    30.times do |n|
      name = Faker::Name.name
      username = "zlearner#{n+1}"
      email = "learner#{n+1}@hankish.com"
      password = "password"
      joined_at = rand(user_start_time..user_end_time)
      user = User.new(:name => name,
                   :username => username,
                   :email => email,
                   :password => password)
      user.flags = ['sample_data']
      user.created_at = joined_at
      user.updated_at = joined_at + 1.hour
      user.skip_confirmation!
      user.timeless.save! if user.valid?
    end
    puts ">> 30 learners created."
  end

  def make_everything_else

    admin_users = User.where(email: /admin\d+@example\.com/i)
    all_users = User.where(email: /@example\.com/i) # include both admins and learners
    
    # create one group for each admin, each with 10 badges
    admin_users.each do |admin|
      name = Faker::Company.name
      url = name.parameterize
      location = "#{Faker::Address.city}, #{Faker::Address.state_abbr}"
      website = Faker::Internet.url
      type = 'open'
      group = Group.new(name: name[0..Group::MAX_NAME_LENGTH-1],
                  url: url[0..Group::MAX_URL_LENGTH-1],
                  location: location[0..Group::MAX_LOCATION_LENGTH-1],
                  website: website,
                  type: type)
      group.flags = ['sample_data']
      group.creator = admin
      group.created_at = admin.created_at
      group.updated_at = Time.now - 2.hours # NOTE: This keeps the emails from firing

      # add members and save group
      all_users.each { |user| group.members << user unless user == admin }
      group.timeless.save!
      puts ">> #{group.url} created."

      # create 10 random badges for each group
      badge_start_time = Time.now - 11.months # this ensures that all users existed before badge create date
      badge_end_time = badge_start_time + 3.months
      @example_data['badge_image_urls'].sample(10).each do |image_url|
        name = Faker::Company.bs.split.map(&:capitalize).join(' ')
        url = name.parameterize
        summary = Faker::Lorem.words(20).join(' ').capitalize()
        badge = Badge.new(name: name[0..Badge::MAX_NAME_LENGTH-1],
           url: url[0..Badge::MAX_URL_LENGTH-1],
           image_url: image_url,
           summary: summary[0..Badge::MAX_SUMMARY_LENGTH-1])
        badge.group = group
        badge.flags = ['sample_data']
        badge.creator = admin
        badge.created_at = rand(badge_start_time..badge_end_time)
        badge.updated_at = Time.now - 2.hours # NOTE: This keeps the emails from firing
        badge.timeless.save!
        puts ">> #{group.url} \\ #{badge.url} created."

        # first, create the randomized variables / example data sets
        log_start_time = badge.created_at
        log_end_time = log_start_time + 6.months
        tags = @example_data['tags'].sample(20) # pick a subset of tags that this badge will use
        images = @example_data['image_urls']
        links = @example_data['link_urls']
        most_active_learner_log = nil
        most_active_learner_count = 0
        
        # now add 11 learners, keep track of the most active one
        print ">> #{group.url} \\ #{badge.url} \\ Building logs..."
        group.members.sample(11).each do |learner_user| 
          join_date = rand(log_start_time..log_end_time)
          log = Log.new(date_started: join_date)
          log.user = learner_user
          log.badge = badge
          log.created_at = join_date
          log.updated_at = Time.now - 2.hours # NOTE: This keeps the emails from firing
          log.flags = ['sample_data']
          number_of_entries = rand(5..50)
          log.next_entry_number = number_of_entries + 1
          log.timeless.save!

          # now make between 5 and 50 log entries
          if number_of_entries > most_active_learner_count
            most_active_learner_log = log
            most_active_learner_count = number_of_entries
          end
          print "|#{number_of_entries}:"
          first_entry_time = rand(join_date..(join_date + 2.days))
          last_entry_time = rand((Time.now - 3.days)..(Time.now - 2.hours))
          increment = (last_entry_time - first_entry_time) / (number_of_entries - 1)
          number_of_entries.times do |i|
            # first initialize the summary and body and the date field
            entry_time = first_entry_time + (i * increment)
            summary = Faker::Lorem.words(20).join(' ').capitalize[0..Entry::MAX_SUMMARY_LENGTH-1]
            number_of_paragraphs = rand(1..5)
            body = ""

            # then build out the content of the body itself
            # the body has 1 to 5 paragraphs, with links & tags randomly inserted between words
            # section breaks and images are randomly inserted between the paragraphs
            (1..number_of_paragraphs).each do |i|
              paragraph = Faker::Lorem.paragraph(1, false, 4)
              words = paragraph.split(/ /)

              stuff_to_add = []
              # add 1 to 3 tags (1/3 probability)
              stuff_to_add += tags.sample(rand(1..3)) if rand(1..3) == 1
              # add 1 link (1/5 probability)
              stuff_to_add << links.sample(1) if rand(1..5) == 1
              stuff_to_add.each { |text| words.insert rand(0..words.count), text }
              body += words.join(' ')

              # now add the dividers if needed
              if i < number_of_paragraphs
                body += "<br><br>" # always add a paragraph separator
                # add image (1/4 probability)
                body += "#{images.sample(1)}<br><br>" if rand(1..4) == 1
                # add section break (1/3 probability)
                body += '-----<br><br>' if rand(1..3) == 1
              end
            end

            # then create the entry
            entry = Entry.new(summary: summary, body: body)
            entry.type = 'post'
            entry.entry_number = i+1
            entry.log = log
            entry.creator = learner_user
            entry.created_at = entry_time
            entry.updated_at = entry_time
            entry.flags = ["sample_data"]
            entry.timeless.save!
            i += 1
            print "."
          end
        end

        # make the most active learner an expert
        # NOTE: We're stealing the body of their first post to make ours look more full-bodied
        most_active_learner_log.add_validation(admin, "True demonstration of mastery", 
          "#{most_active_learner_log.user.name} has absolutely proven mastery of this badge."\
          + " #validation <br>---<br>" + most_active_learner_log.entries.first.body, true)
        puts " >> 11 populated logs created."
      end
    end
  end

end