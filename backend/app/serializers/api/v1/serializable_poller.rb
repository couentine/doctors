class Api::V1::SerializablePoller < Api::V1::SerializableDocument
  extend JSONAPI::Serializable::Resource::ConditionalFields

  type 'poller'

  attribute :status
  
  attribute :progress
  attribute :completed

  attribute :waiting_message
  attribute :completed_message do @object.message end

  attribute :results

  link :self do "/api/v1/pollers/#{@object.id.to_s}" end
  link :self_web do "#{ENV['root_url']}/pollers/#{@object.id.to_s}" end

end