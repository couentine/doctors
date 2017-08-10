class PollersController < ApplicationController

  # GET /pollers/1.json
  # This endpoint checks the status of a poller (only accessible by JSON)
  def show
    respond_to do |format|
      @poller = Poller.find(params[:id]) rescue nil
      format.html do
        if @poller && @poller.redirect_to
          redirect_to @poller.redirect_to, notice: @poller.message
        end # else render show.html.erb
      end
      format.json { render json: @poller }
      format.png do
        begin
          send_data @poller.data['image'].encode('ISO-8859-1'), type: 'image/png', 
            disposition: 'inline'
        rescue
          render nothing: true, status: :ok
        end
      end
    end
  end

end
