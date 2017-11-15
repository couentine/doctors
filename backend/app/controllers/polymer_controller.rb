class PolymerController < ApplicationController

  # GET [any of the polymer paths]
  # This is a single generic action which renders all of the fully polymer views
  def app
    render_polymer_app    
  end

end
