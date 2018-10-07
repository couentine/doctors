#==========================================================================================================================================#
# 
# BADGE BATCH ENDORSEMENT SERVICE
# 
# Use this to bulk insert validations or posts for a particular badge and creator user. There are two different modes in qhich this 
# service operates: validation mode and post mode. Setting the `requirement` key to a non-blank value automatically triggers post mode.
# In post mode you must also specify a `format`, which sets the format and maps the `body` value to the format-specific content field.
# 
# ## Usage Overview ##
# 
# 1. Generate an array of validation items. Each item is a hash of the following format:
# 
#   ```
#  {
#    'email' => 'test@example.com',
#    'name' => 'Jane Doe',
#    'summary' => 'Required summary value',
#    'body' => '<p>This is optional</p><p>If can contain <strong>HTML</strong>.</p>',
#    'requirement' => 'badge-requirement-tag',
#    'format' => 'text',
#  }
#   ```
# 
# 2. Initialize the service. The `send_emails_to_new_users` parameter controls whether badge award emails are sent to non-users.
#   Users wil always get emails, it isn't optional. Upon initialization a poller is automatically created. 
# 
# 3. Start the process by calling the `start()` method. The process will run in a background thread.
#   The poller's `progress` value is used to track the progress. 
# 
# 4. Once the process is complete, result_items will contain a list of the results. The generated list of results will be the same 
#   size and in the same order as the inputted validation items. the poller's `results` array will contain the results as well. 
#   Each validation result item matches the following format:
# 
#   ```
#   {
#     index: 0,
#     type: 'new_user',
#     success: true,
#     error_message: nil
#   }
#   ```

#   Possible result codes are `new_user`, `new_member`, `new_expert`, `existing_seeker`, `existing_holder` and `error`. The result success
#   boolean is merely a handy shortcut indicating whether or not the result code was `error`. If the result is an error then the result
#   error message will be equal to a user-facing explanation of the error, otherwise the error message will be nil.
# 
# ## Example Code ##
# 
# ```
# the_service = BadgeBatchEndorsementService.new(
#   badge: the_badge, 
#   creator_user: the_creator_user, 
#   items: [
#     {
#       'email' => 'test+1@example.com',
#       'summary' => 'Required summary value',
#       'body' => '<p>This is optional</p><p>If can contain <strong>HTML</strong>.</p>'
#     },
#     {
#       'email' => 'test+2@example.com',
#       'summary' => 'A different summary'
#     }
#   ],
#   send_emails_to_new_users: true,
#   poller_waiting_message: 'Wait for it...',
#   poller_completed_message: 'Done!'
# )
# puts "Poller created with id '#{the_service.poller.id.to_s}'."
# the_service.perform
# ```
# 
#==========================================================================================================================================#

class BadgeBatchEndorsementService

  #=== CONSTANTS ===#

  DEFAULT_POLLER_WAITING_MESSAGE = 'Processing batch of badge endorsements...'
  DEFAULT_POLLER_COMPLETED_MESSAGE = 'Badge endorsements processing complete'

  #=== ATTRIBUTES ===#

  attr_reader :group
  attr_reader :badge
  attr_reader :requirement_map
  attr_reader :creator_user
  attr_reader :poller

  attr_reader :items
  attr_reader :result_items

  attr_reader :send_emails_to_new_users

  #=== METHODS ===#

  # Only badge and creator_user are required
  # A poller is automatically created unless no_poller is true.
  # You can optionally provide your own poller (which will then get returned back to you at the end).
  def initialize(group: nil, badge: nil, creator_user: nil, items: [], send_emails_to_new_users: false, 
      no_poller: false, 
      poller: nil, 
      poller_waiting_message: DEFAULT_POLLER_WAITING_MESSAGE, 
      poller_completed_message: DEFAULT_POLLER_COMPLETED_MESSAGE)
    raise ArgumentError.new('Parameter "badge" is missing') if badge.blank?
    raise ArgumentError.new('Parameter "creator_user" is missing') if creator_user.blank?

    @badge = badge
    @group ||= badge.group
    @creator_user = creator_user
    @items = items
    @send_emails_to_new_users = send_emails_to_new_users
    @result_items = []

    @requirement_map = @badge.requirements.map{ |tag| [tag.name, tag] }.to_h

    if !no_poller
      @poller = poller || Poller.create(
        progress: 0,
        waiting_message: poller_waiting_message,
        message: poller_completed_message
      )
    end
  end

  def perform
    @result_items = []
    
    if @poller
      @poller.progress = 0
      @poller.results = []
      @poller.save
    end

    begin
      html_sanitizer = Rails::Html::WhiteListSanitizer.new

      # First check for top-level error states
      raise StandardError.new('Validations list is empty or invalid.') if (items.class != Array) || (items.count == 0)
      item_count = items.count
      processed_item_count = 0

      # Query for existing users and build a map of them by email
      emails = items.select{ |item| !item['email'].blank? }.map{ |item| item['email'].downcase }.uniq
      existing_users = User.where(:email.in => emails)
      user_map = {}
      existing_users.each do |user|
        user_map[user.email] = user
      end

      # Loop through the items and process each one
      items.each_with_index do |item, index|
        result_type = nil
        error_message = nil
        tag = (item['requirement'].present?) ? @requirement_map[item['requirement'].downcase] : nil

        # First we need to sanitize the body html
        if !item['body'].blank?
          item['body'] = html_sanitizer.sanitize(item['body'])
        end

        if item['summary'].blank?
          result_type = 'error'
          error_message = 'Summary is blank'
        elsif !StringTools.is_valid_email?(item['email'])
          result_type = 'error'
          error_message = 'Invalid email'
        elsif user_map.has_key? item['email'].downcase
          # This is an existing user so we add them to the group and badge and then create an item.

          user = user_map[item['email'].downcase]
          user_needs_membership = !user.member_or_admin_of?(@group)
          
          if user_needs_membership && !@group.can_add_members?(@result_items.count + 1)
            result_type = 'error'
            error_message = 'Group is full'
          else
            # Add as a group member if needed and set the status code (we use the most informative result_type possible)
            if user_needs_membership
              result_type = 'new_member'
              @group.members << user 
            elsif user.expert_of? @badge
              result_type = 'existing_holder'
            elsif user.learner_of? @badge
              result_type = 'existing_seeker'
            else
              result_type = 'new_expert'
            end

            # Get or create the log
            log = @badge.add_learner(user)

            # Add or update the item
            if item['requirement'].present?
              if tag.present?
                if (item['format'] == 'image') || (item['format'] == 'file')
                  result_type = 'error'
                  error_message = "Bulk upload of #{item['format']} evidence is not supported"
                elsif Entry::FORMAT_VALUES.include?(item['format'])
                  entry = log.add_post(tag, @creator_user, item['format'], item['summary'], item['body'])
                else
                  result_type = 'error'
                  error_message = 'Invalid post format'
                end
              else
                result_type = 'error'
                error_message = 'Badge requirement not found'
              end
            else
              entry = log.add_validation(@creator_user, item['summary'], item['body'], true, true, true)
            end
          end
        else
          if item['requirement'].present? && !tag.present?
            result_type = 'error'
            error_message = 'Badge requirement not found'
          else
            # This is a new user so we just need to make sure that they are added to the invited members/admins list with a item
            result_type = 'new_user'

            begin
              if tag.present?
                if item['format'] == 'file'
                  result_type = 'error'
                  error_message = 'Bulk upload of file evidence is not supported'
                elsif Entry::FORMAT_VALUES.include?(item['format'])
                  # This will raise an exception if this is a new user invitation and the group is full
                  @group.add_invited_user_post(
                    tag_id: tag.id,
                    current_user_id: @creator_user.id,
                    email: item['email'],
                    badge_url: @badge.url,
                    name: item['name'],
                    format: item['format'],
                    summary: item['summary'],
                    body: item['body'],
                  )
                else
                  result_type = 'error'
                  error_message = 'Invalid post format'
                end
              else
                # This will raise an exception if this is a new user invitation and the group is full
                @group.add_invited_user_validation(
                  current_user_id: @creator_user.id,
                  email: item['email'],
                  badge_url: @badge.url,
                  name: item['name'],
                  summary: item['summary'],
                  body: item['body'],
                  preserve_body_html: true,
                )

                # Now send the email if needed
                if send_emails_to_new_users && !User.get_inactive_email_list.include?(item['email'])
                  NewUserMailer.badge_issued(item['email'], nil, @creator_user.id, @group.id, @badge.id).deliver
                end
              end
            rescue => e
              result_type = 'error'
              error_message = e.to_s
            end
          end
        end
        
        # Add the current item to the processed list
        @result_items << BatchResult.new(
          index: index,
          type: result_type,
          success: (result_type != 'error'),
          error_message: error_message
        )

        # Update the poller progress indicator if needed
        if @poller
          @poller.progress = @result_items.count * 100 / item_count
          @poller.save if @poller.changed?
        end
      end

      # Save the badge and group if needed
      @badge.timeless.save if @badge.changed?
      @group.timeless.save if @group.changed?

      # Close the poller if needed and store the result items in the poller's data hash
      if @poller
        @poller.results = @result_items.map(&:to_h)
        @poller.progress = 100
        @poller.status = 'successful'
        @poller.save
      end

      return @result_items
    rescue => e
      if @poller
        @poller.status = 'failed'
        @poller.message = e.to_s
        @poller.save
      end

      raise e
    end
  end

end