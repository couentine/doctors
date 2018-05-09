# NOTE: Endorsements are a non-model-based abstraction used when bulk creating validations
class Api::V1::EndorsementsController < Api::V1::BaseController

  #=== ACTIONS ===#

  # Only accessible via the create badge endorsements operation for now.
  # Operates in two modes: SINGLE MODE and BATCH MODE.
  # 
  # SINGLE MODE is selected when the body data is a single OBJECT. Example = {
  #   data: {
  #     email: 'test+1@example.com',
  #     summary: 'Required summary value',
  #     body: '<p>This is optional</p><p>If can contain <strong>HTML</strong>.</p>'
  #   },
  #   meta: {
  #     send_emails_to_new_users: true # ==> true is the default if this isn't supplied
  #   }
  # }
  # 
  # BATCH MODE is selected when the body data is an ARRAY. Example (Note the square brackets) = {
  #   data: [
  #     {
  #       email: 'test+1@example.com',
  #       summary: 'Required summary value',
  #       body: '<p>This is optional</p><p>If can contain <strong>HTML</strong>.</p>'
  #     }
  #   ],
  #   meta: {
  #     send_emails_to_new_users: true # ==> true is the default if this isn't supplied
  #   }
  # }
  # 
  # SINGLE MODE returns a 201 response with the data of the result item.
  # BATCH MODE Returns a 202 response with the data of the created poller.
  # 
  def create
    @badge = Badge.find(params[:badge_id])
    skip_authorization

    if @badge.present?
      if !BadgePolicy.new(@current_user, @badge).bulk_award?
        if @badge.group.has? :bulk_tools
          return render_not_authorized
        else
          return render_not_authorized('The group to which this badge belongs does not have the bulk tools feature.')
        end
      end
    else
      return render_not_found
    end

    # Create a deserializer
    deserializer = Api::V1::DeserializableEndorsement.new(params)

    # Now determine the mode
    if deserializer.endorsements.present?
      @mode = :batch
      @endorsements = deserializer.endorsements
      @max_list_size = APP_CONFIG['max_import_list_size']
      
      if @endorsements.count > @max_list_size
        raise ArgumentError.new("You cannot contain submit more than #{@max_list_size} endorsements per request")
      end
    else
      @mode = :single
      @endorsement = deserializer.endorsement
    end
        
    # Send emails to new users defaults to true
    @send_emails_to_new_users = params[:meta].blank? || (params[:meta][:send_emails_to_new_users].to_s != 'false')

    # Now either proceed synchronously or asynchronously depending on the mode
    if @mode == :single
      @result_items = BadgeBatchEndorsementService.new(
        badge: @badge, 
        creator_user: current_user, 
        validation_items: [@endorsement],
        send_emails_to_new_users: @send_emails_to_new_users,
        no_poller: true
      ).perform
      render_json_api @result_items.first, status: 201, expose: { type: 'endorsement_result' }
    else
      @poller = BadgeBatchEndorsementWorker.start(
        badge: @badge, 
        creator_user: current_user, 
        validation_items: @endorsements, 
        send_emails_to_new_users: @send_emails_to_new_users)
      render_json_api @poller, status: 202, root_meta: { endorsements: @endorsements }
    end
  end

end