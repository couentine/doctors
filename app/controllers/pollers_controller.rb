class PollersController < ApplicationController

  # GET /p/1.json
  # This endpoint checks the status of a poller (only accessible by JSON)
  def show
    respond_to do |format|
      @poller = Poller.find(params[:id]) rescue nil
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
