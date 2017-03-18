class ReportResultsController < ApplicationController

  # === FILTERS === #

  prepend_before_action :query_records, only: [:show]
  prepend_before_action :prep_variables, except: [:show]
  before_action :authenticate_user!
  before_action :is_creator_or_bl_admin, only: [:show]

  # === CONSTANTS === #

  PERMITTED_PARAMS = [:type, :format, :parameters]

  # Normal usage is HTML version returns 1st page of results, JSON used to query additional pages
  # GET /report_results?page=2&page_size=12
  # GET /report_results.json?page=2&page_size=12
  def index
    # Get pagination variables
    @page_size = (params['page_size'] || APP_CONFIG['page_size_large']).to_i
    @page_size = [@page_size, APP_CONFIG['page_size_large']].min # cap it at largest
    @page = (params['page'] || 1).to_i

    # Admins can see all results, non-admins only see the ones they've created
    @report_results = (@badge_list_admin ? ReportResult : current_user.report_results)\
      .order_by('created_at desc').page(@page).per(@page_size)
    @report_results_hash = ReportResult.array_json(@report_results, :list_item)
    
    respond_to do |format|
      format.html do
        render layout: 'app'
      end
      format.json do
        render json: { page: @page, page_size: @page_size, report_results: @report_results_hash, 
          next_page: @next_page, success: true }
      end
    end
  end

  # GET /report_results/1
  # GET /report_results/1.json
  def show
    respond_to do |format|
      format.html do
        render layout: 'app'
      end
      format.json do
        if @badge_list_admin
          render json: @report_result.as_json
        else
          render json: @report_result.json(:detail)
        end
      end
    end
  end

  # GET /report_results/new?group=group_url&group_tag=tag_name
  def new
    @groups = current_user.admin_of
    
    if params[:group]
      @selected_group = @groups.where(url: params[:group].to_s.downcase).first
      if params[:group_tag]
        @selected_group_tag = @selected_group.tags\
          .where(name: params[:group_tag].to_s.downcase).first
      end
    end      
  end

  # JSON only, returns hash with keys = [success, poller_id, field_error_messages]
  # If success, then poller_id will be set and field_error_messages will be null
  # If !success, then poller_id will be null and field_error_messages will be a hash of errors
  # POST /report_results.json
  def create
    respond_to do |format|
      format.json do
        rr_params = report_result_params
        rr_params['user'] = current_user
        
        # First we verify the attributes synchronously (avoid starting a poller if params are bad)
        @report_result = ReportResult.new(rr_params)

        if @report_result.valid?
          @poller_id = ReportResult.create_async(rr_params)
          render json: { success: true, poller_id: @poller_id, field_error_messages: nil }
        else
          render json: { success: false, poller_id: nil, 
            field_error_messages: @report_result.errors.messages }
        end
      end
    end
  end

private

  def prep_variables
    @badge_list_admin = current_user && current_user.admin?
  end

  def query_records
    prep_variables

    @report_result = GroupTag.find((params[:id] || params[:report_result_id]).to_s.downcase) \
      || not_found
    @is_creator = current_user && (current_user.id == @report_result.creator_id)
  end

  def is_creator_or_bl_admin
    if !@is_creator && !@badge_list_admin 
      redirect_to '/'
    end
  end

  def report_result_params
    params.require(:group_tag).permit(PERMITTED_PARAMS)
  end

end