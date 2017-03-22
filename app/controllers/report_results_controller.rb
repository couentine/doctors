class ReportResultsController < ApplicationController

  # === FILTERS === #

  prepend_before_action :query_records, only: [:show]
  prepend_before_action :prep_variables, except: [:show]
  before_action :authenticate_user!
  before_action :is_creator_or_bl_admin, only: [:show]

  # === RESTFUL ACTIONS === #

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
    @report_results_polymer = ReportResult.array_json(@report_results, :list_item)
    @next_page = @page + 1 if @report_results.count > (@page_size * @page)
    
    respond_to do |format|
      format.html do
        render layout: 'app'
      end
      format.json do
        render json: { page: @page, page_size: @page_size, report_results: @report_results_polymer, 
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

  # If the type parameter is left off then the user is presented with a report type selector
  # otherwise the user is shown a bl-form to specify the report parameters
  # GET /report_results/new?type=report_type&group=group_url&group_tag=tag_name
  def new
    @type = params['type'] if ReportResult::REPORT_TYPES.has_key?(params['type'])

    # Construct the cancel url, which should return to where we came from
    if params[:group].blank?
      @cancel_url = report_results_url
    else
      if params[:group_tag].blank?
        @cancel_url = "/#{params[:group]}"
      else
        @cancel_url = "/#{params[:group]}/tags/#{params[:group_tag]}"
      end
    end

    if @type.blank?
      @display_mode = 'selector'
      @page_title = 'Run report'
      @report_types_polymer = ReportResult.report_types_list

      # Inject the url into each report type
      @report_types_polymer.each do |item| 
        item[:link] = new_report_result_url(type: item[:key], group: params[:group], 
          group_tag: params[:group_tag])
      end
    else
      @display_mode = 'form'
      @report_type_label = ReportResult::REPORT_TYPES[@type][:label]
      @report_type_icon = ReportResult::REPORT_TYPES[@type][:icon]
      @page_title = "#{@report_type_label} report".downcase.capitalize
      
      @groups = current_user.admin_of.order_by('name asc')
      @groups_polymer = Group.array_json(@groups, :simple_list_item_with_tags)
     
      # Validate the selected params
      if params[:group]
        @selected_group = @groups.where(url: params[:group].to_s.downcase).first
        if params[:group_tag]
          @selected_group_tag = @selected_group.tags\
            .where(name: params[:group_tag].to_s.downcase).first
        end
      end

      # Build out base field spec list, add hidden field for type
      @field_specs_polymer = ReportResult.param_field_specs_for(@type)
      @field_specs_polymer << { key: 'type', type: 'hidden', value: @type, 
        name: 'type' }

      # Next inject options for the group dropdown
      group_field_spec = @field_specs_polymer.find{ |fs| fs[:key] == 'group_id' }
      group_field_spec[:value] = @selected_group.id.to_s if @selected_group
      group_field_spec[:options] = @groups.map do |group|
        { label: group.name, value: group.id.to_s }
      end if group_field_spec

      # Finally build the dependent options for the group tag dropdown
      group_tag_field_spec = @field_specs_polymer.find{ |fs| fs[:key] == 'group_tag_id' }
      group_tag_field_spec[:value] = @selected_group_tag.id.to_s if @selected_group_tag
      if group_tag_field_spec
        group_tag_field_spec[:dependent_options] = {}
        @groups.each do |group|
          if group.tags_cache.blank?
            group_tag_field_spec[:dependent_options][group.id.to_s] \
              = [{ label: 'Group has no tags' }]
          else
            group_tag_field_spec[:dependent_options][group.id.to_s] \
              = [{ label: 'Include all users', value: '' }] \
              + (group.tags_cache.map do |tag_id, tag_item|
                { label: tag_item['name_with_caps'], value: tag_id }
              end).sort_by{ |option| option[:label] }
          end
        end
      end
    end

    render layout: 'app'    
  end

  # JSON only, returns hash with keys = [success, poller_id, field_error_messages]
  # If success, then poller_id will be set and field_error_messages will be null
  # If !success, then poller_id will be null and field_error_messages will be a hash of errors
  # POST /report_results.json
  def create
    respond_to do |format|
      format.json do
        rr_params = report_result_params
        rr_params['user_id'] = current_user.id.to_s
        rr_params['format'] = 'csv' # This is the only format supported for now
        
        # First we verify the attributes synchronously (avoid starting a poller if params are bad)
        @report_result = ReportResult.new(rr_params)

        if @report_result.valid?
          @poller_id = ReportResult.create_async(rr_params)
          render json: { success: true, poller_id: @poller_id.to_s, field_error_messages: nil }
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

    @report_result = ReportResult.find((params[:id] || params[:report_result_id]).to_s.downcase) \
      || not_found
    @is_creator = current_user && (current_user.id == @report_result.user_id)
  end

  def is_creator_or_bl_admin
    if !@is_creator && !@badge_list_admin 
      redirect_to '/'
    end
  end

  def report_result_params
    params.require(:report_result).permit(ReportResult.permitted_params)
  end

end