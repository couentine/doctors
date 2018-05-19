class Api::V1::PollersController < Api::V1::BaseController

  #=== ACTIONS ===#

  def show
    @poller = Poller.find(params[:id])

    if @poller
      authorize @poller # always returns true, all pollers are public
      
      render_json_api @poller
    else
      skip_authorization

      render_not_found
    end
  end

end