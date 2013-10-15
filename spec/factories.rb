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
  
end