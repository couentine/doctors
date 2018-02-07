class Api::V1::GroupsController < Api::V1::BaseController

  def index
    set_initial_pagination_variables
    if current_user.present?
      @groups = current_user.groups(false).asc(:name).page(@page).per(@page_size)
    else
      @groups = []
    end
    set_calculated_pagination_variables(@groups)

    render_json_api @groups
  end

  def show
    @group = Group.find(params[:id])

    if @group
      @group.current_user = current_user # FIXME ==> Do this somewhere else. Anywhere else.
      render_json_api @group
    else
      render_not_found
    end
  end

end