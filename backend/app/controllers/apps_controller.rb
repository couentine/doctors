class AppsController < ApplicationController

  def show
    @app = App.find(params[:id])

    if @app.blank?
      render_polymer_app 'App Not Found - Badge List'
    else
      render_polymer_app("#{@app.name} App - Badge List", {
        'include_metadata' => true,
        'metadata_title' => "#{@app.name} App on Badge List",
        'metadata_description' => @app.summary,
        'metadata_image' => @app.image_url,
        'metadata_image_width' => '500',
        'metadata_image_height' => '500',
        'metadata_site_name' => 'Badge List',
        'metadata_url' => request.original_url
      })
    end
  end

end
