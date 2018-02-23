class Api::V1::SerializableBadge < Api::V1::SerializableDocument
  extend JSONAPI::Serializable::Resource::ConditionalFields

  type 'badge'

  attribute :record_path
  attribute :parent_path
  attribute :slug do @object.url end
  attribute :slug_with_caps do @object.url_with_caps end
  
  attribute :name,                        if: -> { @show_all_fields }
  attribute :summary,                     if: -> { @show_all_fields }

  attribute :validation_request_count,    if: -> { @show_all_fields }
  attribute :learner_count,               if: -> { @show_all_fields }
  attribute :image_url,                   if: -> { @show_all_fields }
  attribute :image_medium_url,            if: -> { @show_all_fields }
  attribute :image_small_url,             if: -> { @show_all_fields }

  link :self do @object.full_path end
  link :parent do "/#{@object.group_url_with_caps || @object.group.url_with_caps}" end

end