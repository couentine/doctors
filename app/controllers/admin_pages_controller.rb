class AdminPagesController < ApplicationController

  before_action :badge_list_admin
  
  # GET /a
  # This shows the main admin tools menu
  def index
    # Nothing to do here
  end

private

  def badge_list_admin
    unless current_user && current_user.admin?
      redirect_to '/'
    end  
  end

end
