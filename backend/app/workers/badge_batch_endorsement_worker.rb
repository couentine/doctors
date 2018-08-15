#==========================================================================================================================================#
# 
# BADGE BATCH ENDORSEMENT WORKER
# 
# This is a wrapper around BadgeBatchEndorsementService. Use it to run a BBE Service in a background thread. Refer to the comments in 
# BadgeBatchEndorsementService for usage details.
# 
# ## Usage Overview ##
# 
# Option 1 (Recommended): Use the start method to create a poller. Returns the poller.
# 
# ```
# the_poller = BadgeBatchEndorsementWorker.start(the_badge, the_creator_user, [
#   items: [
#     {
#       'email' => 'test+1@example.com',
#       'summary' => 'Required summary value',
#       'body' => '<p>This is optional</p><p>If can contain <strong>HTML</strong>.</p>'
#     },
#     {
#       'email' => 'test+2@example.com',
#       'summary' => 'A different summary'
#     },
#     {
#       'email' => 'test+2@example.com',
#       'summary' => 'A different summary'
#     }
#   ], true)
# puts "Batch endorsement started in background thread with poller id '#{the_poller.id.to_s}'."
# ```
# 
# Option 2: Fire the worker manually.
# 
# ```
# my_custom_poller = Poller.create()
# BadgeBatchEndorsementWorker.perform_async(badge.id, creator_user.id, items, true, my_custom_poller.id)
# ```
# 
#==========================================================================================================================================#

class BadgeBatchEndorsementWorker
  include Sidekiq::Worker
  sidekiq_options queue: :default, retry: :false

  # Returns the poller created by the service
  def self.start(badge: nil, creator_user: nil, items: [], send_emails_to_new_users: false)
    service = BadgeBatchEndorsementService.new(
      badge: badge, 
      creator_user: creator_user, 
      items: items,
      send_emails_to_new_users: send_emails_to_new_users
    )

    BadgeBatchEndorsementWorker.perform_async(badge.id.to_s, creator_user.id.to_s, items, send_emails_to_new_users, 
      service.poller.id.to_s)
    
    return service.poller
  end

  def perform(badge_id, creator_user_id, items, send_emails_to_new_users, poller_id)
    badge = Badge.find(badge_id)
    creator_user = User.find(creator_user_id)
    poller = Poller.find(poller_id)

    service = BadgeBatchEndorsementService.new(
      badge: badge, 
      creator_user: creator_user, 
      items: items,
      send_emails_to_new_users: send_emails_to_new_users,
      poller: poller
    )
    service.perform

    return true
  end

end