FactoryGirl.define do

  factory :badge do
    sequence(:name)  { |n| "Badge #{n}" } 
    image_url "http://example.com/image.png"
    summary "Lorem ipsum"
    description "Lorem ipsum doler sit amet."
  end

  factory :user do
    sequence(:name)  { |n| "Human Being #{n}" }
    sequence(:email) { |n| "human_#{n}@example.com"}
    password "password"
    password_confirmation { "password" }
  end

  factory :group do
    sequence(:name)  { |n| "Learning Group #{n}" }
    sequence(:url)  { |n| "zzz-uniquegroup-#{n}" }
    location "San Franciso, CA"
    website "http://example.com"
    type "open"
    association :creator, :factory => :user
  end
  
end