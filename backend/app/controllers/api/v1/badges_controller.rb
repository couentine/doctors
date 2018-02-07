class Api::V1::BadgesController < Api::V1::BaseController

  # GET /badges?page=1
  # This returns a list of the current user's badges in progress
  def index
    set_initial_pagination_variables
    if current_user.present?
      @badges = Badge.where(:id.in => current_user.learner_badge_ids).asc(:name).page(@page).per(@page_size)
    else
      @badges = []
    end
    set_calculated_pagination_variables(@badges)

    render_json_api @badges
  end


  # GET /badges/{badge_id}
  # GET /badges/{badge_url}?parent_path={group_url}
  # Returns badge API json
  # Note: The id parameter can either be a record id or a string of the format `group-url.badge-url`. Refer to `Badge.find()` for more info.
  def show
    if (params[:parent_path])
      @group = Group.find(params[:parent_path]) || not_found!
      @badge = @group.badges.where(url: params[:id].to_s.downcase).first
    else
      @badge = Badge.find(params[:id])
    end

    if @badge
      @badge.current_user_accessor = current_user # FIXME ==> Do this somewhere else. Anywhere else.
      render_json_api @badge
    else
      render_not_found
    end
  end

end