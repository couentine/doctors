class Api::V1::SerializableBadge < Api::V1::SerializableDocument
  extend JSONAPI::Serializable::Resource::ConditionalFields

  type 'badge'

  attribute :slug do @object.url_with_caps end
  
  attribute :name,                        if: -> { @show_all_fields }
  attribute :summary,                     if: -> { @show_all_fields }

  attribute :feedback_request_count,      if: -> { @show_all_fields } do 
    @object.validation_request_count
  end
  attribute :seeker_count,                if: -> { @show_all_fields } do 
    @object.learner_count
  end
  attribute :holder_count,                if: -> { @show_all_fields } do 
    @object.expert_count
  end
  attribute :image_url,                   if: -> { @show_all_fields }
  attribute :image_medium_url,            if: -> { @show_all_fields }
  attribute :image_small_url,             if: -> { @show_all_fields }

  link :self do "/api/v1/badges/#{@object.id.to_s}" end

  belongs_to :group do
    link :self do "/api/v1/groups/#{@object.group_id.to_s}" end
  end

end