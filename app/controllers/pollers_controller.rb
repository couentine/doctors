class PollersController < ApplicationController

  # GET /p/1.json
  # This endpoint checks the status of a poller (only accessible by JSON)
  def show
    respond_to do |format|
      format.json do
        @poller = Poller.find(params[:id]) rescue nil
        render json: @poller
      end
    end
  end

end
