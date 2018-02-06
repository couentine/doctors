class Api::V1::GroupsController < Api::V1::BaseController

  def jsonapi_class 
    { Group: Api::V1::SerializableGroup }
  end

  def index
    set_initial_pagination_variables
    if current_user.present?
      @groups = current_user.groups(false).asc(:name).page(@page).per(@page_size)
    else
      @groups = []
    end
    set_calculated_pagination_variables(@groups)

    render jsonapi: @groups, meta: get_pagination_variables.merge({current_user: @current_user})
  end

  def show
    @group = Group.find(params[:id])

    if @group
      @group.current_user = current_user # FIXME ==> Do this somewhere else. Anywhere else.
      render jsonapi: @group
    else
      not_found!
    end
  end

end