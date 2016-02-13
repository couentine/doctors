class BadgeMakerController < ApplicationController

  before_action :authenticate_user!  

  # GET /i.json?frame=square&icon=pencil&c1=ffffff&c2=000000
  # Starts asyncronous generation of the badge image and returns the poller id
  def show
    @frame = params[:frame]
    @icon = params[:icon]
    @color1 = params[:c1]
    @color2 = params[:c2]

    respond_to do |format|
      format.json do     
        @poller_id = BadgeMaker.build_image(async: true, frame: @frame, icon: @icon, 
          color1: @color1, color2: @color2)
        render json: { poller_id: @poller_id.to_s }
      end
    end
  end

end
