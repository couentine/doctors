class PolymerController < ApplicationController

  # GET [any of the polymer paths]
  # This is a single generic action which renders all of the fully polymer views
  def show
    # The routing is handled in the polymer frontend so there's nothing to do here except
    # generate the manifest file that we pass to the frontend app.
    @manifest = {
      app_root_url: ENV['root_url'],
      polymer_root_url: @polymer_app_root_url,
      csrf_token: form_authenticity_token,
      current_user: (current_user.present?) ? current_user.json(:current_user) : nil
    }

    render layout: 'polymer'
  end

end
