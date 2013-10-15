namespace :db do
  desc "Fill database with sample data"
  task populate: :environment do
    make_users
    make_badges
  end
end

def make_users
  
  50.times do |n|
    name = Faker::Name.name
    email = "human-#{n+1}@example.com"
    password = "password"
    User.create!(:name => name,
                 :email => email,
                 :password => password)
  end

end

def make_badges
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

  badge_words = [
      "Excel Ninja",
      "Expert Cook",
      "Yogalicious",
      "I Know Kung Fu",
      "Skilled Game Designer",
      "Art Appreciator",
      "Highly Connected Social Media User",
      "Data Structure Master",
      "Leadership",
      "CAD Modeled Auto Lathe Expert",
      "Organic Chemistry Beginner",
      "Fully Versed in HTML 5",
      "Top Notch Briefcase Carrier",
      "PHP Developer",
      "Advanced Vocal Coach",
      "Wilderness Survivalist",
      "iOS App Store Developer",
      "Expert Programmer",
      "Data Architecture & Modeling"
    ]

  50.times do |n|
    name = "Group " + ((n / badge_words.length).floor + 1).to_s + ": " + badge_words[n % badge_words.length]
    image_url = badge_image_urls[n % badge_image_urls.length]
    summary = Faker::Lorem.sentence(4)
    description = "<p>" + Faker::Lorem.paragraphs(3).join("</p><p>") + "</p>"
    Badge.create!(:name => name,
                 :image_url => image_url,
                 :summary => summary,
                 :description => description)
  end

end