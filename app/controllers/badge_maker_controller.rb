class BadgeMakerController < ApplicationController

  before_filter :authenticate_user!  

  # GET /i?frame=square&icon=pencil&c1=ffffff&c2=000000
  # Returns the badge image 
  # (used primarily to show the preview in the badge image building interface)
  def show
    @frame = params[:frame]
    @icon = params[:icon]
    @color1 = params[:c1]
    @color2 = params[:c2]

    send_data BadgeMaker.build_image(@frame, @icon, @color1, @color2).to_blob, 
      type: "image/png", disposition: "inline"
  end

end
