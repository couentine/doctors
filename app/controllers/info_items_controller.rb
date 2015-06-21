class InfoItemsController < ApplicationController

  # === FILTERS === #

  before_filter :badge_list_admin

  # GET /a/info_items
  # Accepts page parameters: page, page_size, sort_by, sort_order, type
  def index
    # Grab the current page of groups
    @page = params[:page] || 1
    @page_size = params[:page_size] || APP_CONFIG['page_size_normal']
    @sort_by = params[:sort_by] || "created_at"
    @sort_order = params[:sort_order] || "desc"
    @type = params[:type]
    if @type
      @info_items = InfoItem.where(type: @type).order_by("#{@sort_by} #{@sort_order}")\
        .page(@page).per(@page_size)
    else
      @info_items = InfoItem.order_by("#{@sort_by} #{@sort_order}").page(@page).per(@page_size)
    end

    respond_to do |format|
      format.html # index.html.erb
      format.json { render json: @info_items }
    end
  end

  # GET /a/info_items/1.json
  def show
    respond_to do |format|
      format.json do
        @info_item = InfoItem.find(params[:id]) rescue nil
        render json: @info_item
      end
    end
  end

private

  def badge_list_admin
    unless current_user && current_user.admin?
      redirect_to '/'
    end  
  end

end