FactoryGirl.define do

  factory :badge do
    sequence(:name)  { |n| "Badge #{n}" } 
    image_url "http://example.com/image.png"
    summary "Lorem ipsum"
    description "Lorem ipsum doler sit amet."
  end

end