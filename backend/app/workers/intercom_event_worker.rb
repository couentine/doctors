class IntercomEventWorker
  include Sidekiq::Worker
  sidekiq_options queue: :low
  
  # This worker submits an event to Intercom.io

  # Required options: event_name, created_at [unix timestamp], and (email OR user_id)
  # Optional option: metadata
  def perform(options = {})
    intercom = Intercom::Client.new(
      token: ENV['INTERCOM_TOKEN']
    )
    begin
      intercom.events.create(options)
    rescue => e
      if options['user_id'].present?
        intercom_user = intercom.users.find(user_id: options['user_id']) rescue nil
        user = User.find(options['user_id']) rescue nil
      elsif options['email'].present?
        intercom_user = intercom.users.find(email: options['email']) rescue nil
        user = User.find_by(email: options['email']) rescue nil
      else
        raise e
      end

      if intercom_user.present? || !user.present?
        # If there *is* a matching intercom user then this is a real error... throw it. (Also if there's not matchin bl user)
        raise e
      else
        # If there is a bl user but there is *not* an intercom user then this is a user not found error, just go ahead and create the user
        intercom_user = intercom.users.create(email: user.email, name: user.name, user_id: user.id.to_s, signed_up_at: user.created_at.to_i)

        # Try one more time, if this one errors then just fail
        options['user_id'] = user.id.to_s if options['user_id'].blank?
        intercom.events.create(options)
      end
    end
  end
end