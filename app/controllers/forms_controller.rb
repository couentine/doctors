class FormsController < ApplicationController

  # === FILTERS === #

  before_filter :authenticate_user!, only: [:user_demo]

  # === CONSTANTS === #

  TARGET_EMAIL = "hello@badgelist.com" # This is where the email notifications are sent.

  # POST /f/talk-with-us?goals={text}&availability={text}
  # This form allows the current user to schedule a time to talk with us.
  # Posting to this action will send an email to TARGET_EMAIL and store the content
  # of the form submissions to user.form_submissions
  def user_discussion
    # First get the parameters from the url
    goals = params[:goals]
    availability = params[:availability]

    # Now update the user record
    current_user.set_flag "form-user-discussion"
    current_user.form_submissions = [] if current_user.form_submissions.nil?
    current_user.form_submissions << {
      "date" => Time.now,
      "goals" => goals,
      "availability" => availability
    }
    current_user.save

    # Finally send the email and return only javascript
    SystemMailer.delay.form_user_discussion(TARGET_EMAIL, current_user, goals, availability).deliver
    respond_to do |format|
      format.js {} # render user_discussion.js.erb
    end
  end

  # POST /f/contact-us
  # FIXME >> This hasn't been coded yet.
  def contact_us
    # This form will allow anonymous users to submit contact requests 
  end

end
