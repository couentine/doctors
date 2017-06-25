class LtiController < ApplicationController

  # === FILTERS === #

  skip_before_filter :verify_authenticity_token

  # === CONSTANTS === #
  
  MAX_TIMESTAMP_DELTA = 5.minutes # if oauth timestamp is outside of +/- this, then it is rejected

  # === ACTIONS === #

  # POST /h/lti/launch
  # This endpoint receives LTI launch requests from an integrated LMS
  # It checks the LTI status and redirects the user according to the group's LTI configuration.
  # If there is an issue it displays an iframe-safe error screen.
  def launch
    begin
      @lti_status = Group.get_lti_status(params)
      @group = @lti_status[:group]
      @lti_context_details = @lti_status[:lti_context_details]
      @lti_pending_key_details = @lti_status[:lti_pending_key_details]

      case @lti_status[:status]
      when 'ready', 'pending'
        # First we need to verify the oauth signature
        secret_key = (@lti_context_details || @lti_pending_key_details)['secret_key']
        timestamp_delta = (Time.now.to_i - params['oauth_timestamp'].to_i).abs

        if (timestamp_delta < MAX_TIMESTAMP_DELTA) \
            && OAuth::Signature.verify(request, consumer_secret: secret_key)
          # If this is pending then we now have all the info needed to register it
          if @lti_status[:status] == 'pending'
            begin
              @lti_context_details = @group.register_pending_lti_key(params)
              @group.save!
              @new_context_registration = true # redirects to integrations panel if user is admin
            rescue Exception => e
              @error_title = 'There was an error registering your LTI integration'
              @error_message = "<p><strong>Error Details:</strong> #{e.message}</p>"
              render 'errors/error_no_container', layout: 'app'
            end
          end

          # If we've got context info then we are ready to log the user in
          if @lti_context_details.present?
            begin
              @user = User.from_lti(params, @group)
              
              if @user.persisted?
                sign_in @user, event: :authentication

                # Now we need to determine where to redirect the user. Step 1: is this a new setup?
                if @new_context_registration
                  if @user.admin_of? @group
                    @navigate_to_path = group_path(@group) + '#integrations'
                    flash[:notice] = 'Your LTI integration is now configured! You can now use ' \
                      + 'the integrations panel to control where users are navigated to when ' \
                      + 'they click the link in your LMS.'
                  else
                    # This user doesn't have access to the integrations panel, so we'll just
                    # post an explanatory notice.
                    flash[:notice] = 'The LTI integration is now configured! The group admins ' \
                      + 'have been sent an email with instructions for how to customize the setup.'
                  end
                end

                # If we still don't have a navigate to path, check for a badge/tag navigation
                if @navigate_to_path.blank? && @lti_context_details['navigate_to_id'].present?
                  if @lti_context_details['navigate_to'] == 'badge'
                    @badge = @group.badges.where(id: @lti_context_details['navigate_to_id']).first
                    @navigate_to_path = group_badge_path(@group, @badge) if @badge
                  elsif @lti_context_details['navigate_to'] == 'group_tag'
                    @group_tag = @group.tags.where(id: @lti_context_details['navigate_to_id']).first
                    @navigate_to_path = group_tag_path(@group, @group_tag) if @group_tag
                  end
                end

                # If we *still* don't have a navigate to path then just navigate to the group
                @navigate_to_path = group_path(@group) if @navigate_to_path.blank?

                redirect_to @navigate_to_path
              else 
                # There was some sort of problem
                raise StandardError.new('A user record could not be created due to a system ' \
                  + 'error. Please try again later.')
              end
            rescue Exception => e
              @error_title = 'There was an error logging you in'
              @error_message = "<p><strong>Error Details:</strong> #{e.message}</p>"
              render 'errors/error_no_container', layout: 'app'
            end
          end
        else
          @error_title = 'OAuth Error'
          @error_message = '<p>The OAuth signature, which is used to ensure secure ' \
            + 'communications between Badge List and the LMS, is inaccurate. ' \
            + 'Please contact your site administrator.</p>'
          render 'errors/error_no_container', layout: 'app'
        end
      when 'inactive'
        @error_title = 'Your group has an inactive subscription'
        @error_message = "<p>#{@lti_status[:error_message]}</p>"
        render 'errors/error_no_container', layout: 'app'
      else # assume 'invalid'
        @error_title = 'There was a problem loading your group'
        @error_message = "<p>#{@lti_status[:error_message]}</p>"
        render 'errors/error_no_container', layout: 'app'
      end
    rescue Exception => e
      @error_title = 'LTI Integration Error'
      @error_message = '<p>Badge List encountered an error trying to load your group. ' \
        + 'There may be a problem with the LTI configuration. ' \
        + 'Please contact your LMS administrator.</p>' \
        + "<p><strong>Error Details:</strong> #{e.message}</p>"
      render 'errors/error_no_container', layout: 'app'
    end

  end

end
