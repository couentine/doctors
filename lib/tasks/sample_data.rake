namespace :db do
  desc "Fill database with sample data"
  task populate: :environment do
    make_users
    make_groups_with_badges
  end

  def make_users
    # make admins
    5.times do |n|
      name = Faker::Name.name
      email = "admin#{n+1}@example.com"
      password = "password"
      user = User.new(:name => name,
                   :email => email,
                   :password => password)
      user.skip_confirmation!
      user.save! if user.valid?
    end

    # make learners
    50.times do |n|
      name = Faker::Name.name
      email = "learner#{n+1}@example.com"
      password = "password"
      user = User.new(:name => name,
                   :email => email,
                   :password => password)
      user.skip_confirmation!
      user.save! if user.valid?
    end
  end

  def make_groups_with_badges

    badge_image_urls = [
        "http://a1.distilledcdn.com/wp-content/uploads/2012/03/excel-badge.png",
        "http://mattersofgrey.com/wp-content/uploads/2010/11/bravo_top_chef_big.png",
        "http://www.leanteen.com/file/pic/badge/2013/04/ede7ab02976755991fb69412c7860aa5.png",
        "http://upload.wikimedia.org/wikipedia/en/8/87/Kuk_sool_won_logo.png",
        "http://teens.denverlibrary.org/sites/teens/files/gamedesign.png",
        "http://foursquareguru.com/media/badges/moma_big.png",
        "http://iconbug.com/data/f3/256/600fff96f94015434f9371d881630203.png",
        "https://wac.a8b5.edgecastcdn.net/80A8B5/badges/badges_iPhone_BlogReader_Stage4.png",
        "http://www.dallasmuseumofart.org/idc/groups/web_view/documents/dma_images/dma_517998.png",
        "https://badge.chicagosummeroflearning.org/badge/image/math-by-design.png",
        "http://s3.amazonaws.com/commendablekids.com.prod/badges/45/large.png?1287262798",
        "http://tantek.com/presentations/2011/10/html5-now/HTML5_Badge_512.png",
        "http://www.textually.org/textually/archives/2010/11/25/Baggage%20Handler%20badge.png",
        "https://wac.a8b5.edgecastcdn.net/80A8B5/badges/badges_eCommerce_Stage1.png",
        "http://24.media.tumblr.com/48052bc0427c0c48a1a3f0777b0ff6d6/tumblr_mjyumk4gbK1rha3vbo1_500.png",
        "http://31.media.tumblr.com/8ef0864859850a8594b3cf4271835688/tumblr_mg7kdnpbD71rha3vbo1_500.png",
        "https://wac.a8b5.edgecastcdn.net/80A8B5/badges/badges_iPhone_CrystalBall_Stage6.png",
        "https://wac.a8b5.edgecastcdn.net/80A8B5/badges/badges_eCommerce_Stage2.png",
        "https://wac.a8b5.edgecastcdn.net/80A8B5/badges/badges_DD_Database_Stage2.png"
      ]

    admin_users = User.where(email: /admin\d+@example\.com/i)
    all_users = User.where(email: /@example\.com/i) # include both admins and learners
    
    admin_users.each do |admin|
      # create one group for each admin
      name = Faker::Company.name
      url = name.parameterize
      location = "#{Faker::Address.city}, #{Faker::Address.state_abbr}"
      website = Faker::Internet.url
      type = 'open'
      group = Group.new(name: name[0..Group::MAX_NAME_LENGTH-1],
                  url: url[0..Group::MAX_URL_LENGTH-1],
                  location: location[0..Group::MAX_LOCATION_LENGTH-1],
                  website: website,
                  type: type,
                  creator: admin)

      # add members and save group
      all_users.each { |user| group.members << user unless user == admin }
      group.save!

      # create 10 random badges for each group
      badge_image_urls.sample(10).each do |image_url|
        name = Faker::Company.bs.split.map(&:capitalize).join(' ')
        url = name.parameterize
        summary = Faker::Lorem.sentence(4)
        info = "<h3>Overview</h3><p>First, a cute kitten:<br/>img:http://bit.ly/1bEupcD</p>"
        info += "<p>---</p>  <h3>Relevant Links</h3><p>These may be of interest <ul><li>http://google.com</li><li>http://yahoo.com</li></ul><br/>Plus, #here #are #hash-tags.</p> <p>---</p>"
        info += "<p>" + Faker::Lorem.paragraphs(3).join("</p><p>") + "</p>"
        Badge.create!(name: name[0..Badge::MAX_NAME_LENGTH-1],
           url: url[0..Badge::MAX_URL_LENGTH-1],
           image_url: image_url,
           summary: summary,
           info: info,
           group: group,
           creator: admin)
      end
    end
  end

end