class ReportResultsController < ApplicationController

  # === FILTERS === #

  prepend_before_action :query_records, only: [:show]
  prepend_before_action :prep_variables, except: [:show]
  before_action :authenticate_user!
  before_action :is_creator_or_bl_admin, only: [:show]

  # GET /report_results/1
  # GET /report_results/1.json
  def show
    respond_to do |format|
      format.json do
        if @badge_list_admin
          render json: @report_result.as_json
        else
          render json: @report_result.json(:detail)
        end
      end
      format.html # render show.html.erb
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

  # JSON only, returns poller / poller id if report results is successfully created.
  # POST /report_results?report_result[]=...
  def create
    rr_params = params['report_result']
    @report_result = ReportResult.build(current_user.id, rr_params['type'], 'json', 
      rr_params['parameters'], async: true)

    if @report_result.valid? # ==> Left off here. 
      redirect_to report_result_path(@group, @report_result), notice: 'Report result was successfully created.'
    else
      redirect_to @group, 
        alert: "There was a problem creating a tag called #{@report_result.name_with_caps}. " \
          + 'Try creating a tag with a different name.'
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

end