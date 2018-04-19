class Api::V1::SerializablePortfolio < Api::V1::SerializableDocument
  extend JSONAPI::Serializable::Resource::ConditionalFields

  type 'portfolio'

  attribute :status
  
  attribute :badge_id do
    @object.badge_id.to_s
  end
  attribute :user_id do
    @object.user_id.to_s
  end
  attribute :user_name
  attribute :user_username do 
    @object.user_username_with_caps 
  end

  attribute :show_on_badge
  attribute :show_on_profile

  attribute :date_started
  attribute :date_requested
  attribute :date_withdrawn
  attribute :date_issued
  attribute :date_retracted
  attribute :date_originally_issued
  
  link :self do "/api/v1/portfolios/#{@object.id.to_s}" end

  belongs_to :badge do
    link :self do "/api/v1/badges/#{@object.badge_id.to_s}" end
  end
  belongs_to :user do
    link :self do "/api/v1/users/#{@object.user_id.to_s}" end
  end

end