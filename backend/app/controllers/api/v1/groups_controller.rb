class Api::V1::GroupsController < Api::V1::BaseController

  def index
    authorize :group # rejects if current user is blank

    set_initial_pagination_variables
    @groups = @current_user.groups(false).asc(:name).page(@page).per(@page_size)
    set_calculated_pagination_variables(@groups)

    @policy = Pundit.policy(@current_user, @groups)
    render_json_api @groups, expose: { meta_index: @policy.meta_index }
  end

  def show
    @group = Group.find(params[:id]) rescue nil

    if @group
      authorize @group

      @policy = Pundit.policy(@current_user, @group)
      render_json_api @group, expose: { meta: @policy.meta }
    else
      skip_authorization

      render_not_found
    end
  end

end