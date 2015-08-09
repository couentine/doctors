class StaticPagesController < ApplicationController

  # GET /c
  # This shows the current color scheme for the app
  def colors
    # Nothing to do here
  end

  # GET /j/image_key?key=abc123
  # This is used with carrier direct to pass the image key from a child iframe window into the 
  # parent page. It will take the key parameter and pass it as an argument to the javascript 
  # function processImageKey().
  def image_key
    render layout: false
  end

end
