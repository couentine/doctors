class IntercomEventWorker
  include Sidekiq::Worker
  sidekiq_options queue: :low
  
  # This worker submits an event to Intercom.io

  # Required options: event_name, created_at [unix timestamp], and (email OR user_id)
  # Optional option: metadata
  def perform(options = {})
    intercom = Intercom::Client.new(
      app_id: ENV['INTERCOM_APP_ID'], 
      api_key: ENV['INTERCOM_API_KEY']
    )
    intercom.events.create(options)
  end
end