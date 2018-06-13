class Api::V1::PollersController < Api::V1::BaseController

  #=== ACTIONS ===#

  # NOTE: Pollers are by definition fully public and are intended to query / run as quickly as possible.
  #   For that reason we want to keep this method super light, with no non-critical code.
  def show
    skip_authorization
    @poller = Poller.find(params[:id]) rescue nil
    return render_not_found if @poller.blank?
    render_json_api @poller
  end

end