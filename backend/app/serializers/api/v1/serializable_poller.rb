class Api::V1::SerializablePoller < JSONAPI::Serializable::Resource
  # Note: We're trying to keep pollers as fast and light as possible so we inherit directly from the JSON API RB class.
  type 'poller'

  #=== FIELDS ===#

  id { @object.id.to_s }

  attribute :created_at do
    @object.created_at.iso8601 if @object.created_at
  end
  attribute :updated_at do
    @object.updated_at.iso8601 if @object.updated_at
  end

  attribute :status
  attribute :progress
  attribute :completed
  attribute :waiting_message
  attribute :completed_message do
    @object.message
  end
  attribute :results

  #=== LINKS ===#
  link :self do 
    "/api/v1/pollers/#{@object.id.to_s}"
  end
  link :self_web do 
    "#{ENV['root_url']}/pollers/#{@object.id.to_s}" 
  end
end