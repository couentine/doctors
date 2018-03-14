class Api::V1::BadgesController < Api::V1::BaseController

  def index
    authorize :badge # rejects if current user is blank

    set_initial_pagination_variables
    @badges = Badge.where(:id.in => @current_user.learner_badge_ids).asc(:name).page(@page).per(@page_size)
    set_calculated_pagination_variables(@badges)

    @policy = Pundit.policy(@current_user, @badges)
    render_json_api @badges, expose: { show_all_fields: true, meta_index: @policy.meta_index }
  end

  def show
    if params[:parent_path].present?
      @badge = Badge.find(params[:parent_path] + '.' + params[:id])
    else
      @badge = Badge.find(params[:id])
    end

    if params[:include] == 'group'
      @include = [:group]
    else
      @include = nil
    end

    if @badge
      authorize @badge # always returns true, fields are filtered in the serializer
      
      @policy = Pundit.policy(@current_user, @badge)
      render_json_api @badge, expose: { show_all_fields: @policy.show_all_fields?, meta: @policy.meta }, include: @include
    else
      skip_authorization

      render_not_found
    end
  end

end