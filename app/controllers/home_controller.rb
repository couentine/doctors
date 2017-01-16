class HomeController < ApplicationController

  # GET /?gp=1&bp=1&query=group
  # This renders the appropriate root layout based on whether user is signed in
  def root
    if current_user
      @user = current_user
      @current_user_json = current_user.json_cu
      @page_size = APP_CONFIG['page_size_small']
      @query = params[:query] || 'all'
      @badge_count = @user.expert_badge_ids.count # doesn't result in a query

      if @query.in? ['all', 'groups']
        @groups_current_page = (params[:gp] || 1).to_i
        @groups_hash = @user.groups(false).asc(:name).page(@groups_current_page).per(@page_size)\
            .map do |group| 
          j = group.json(:list_item)
          j['member_type'] = @user.member_type_of(group.id).to_s # = ['admin', 'member', 'none']
          j
        end
        
        if @user.groups(false).count > (@page_size * @groups_current_page)
          @groups_next_page = @groups_current_page + 1
        else
          @groups_next_page = nil
        end
      end
      
      if @query.in? ['all', 'badges']
        @badges_current_page = (params[:bp] || 1).to_i
        @badges_hash = Badge.where(:id.in => @user.learner_badge_ids).asc(:name)\
            .page(@badges_current_page).per(@page_size).map { |badge| badge.json(:list_item) }
        
        if Badge.where(:id.in => @user.learner_badge_ids).count > (@page_size*@badges_current_page)
          @badges_next_page = @badges_current_page + 1
        else
          @badges_next_page = nil
        end
      end

      respond_to do |format|
        format.html do
          render template: 'home/root_internal', layout: 'app' 
        end
        format.json do
          if @query == 'groups'
            render json: { next_page: @groups_next_page, groups: @groups_hash }
          elsif @query == 'badges'
            render json: { next_page: @badges_next_page, badges: @badges_hash }
          else
            render json: nil
          end
        end
      end
    else
      @current_user_json = '{}'
      respond_to do |format|
        format.html { render template: 'home/root_external', layout: 'web' }
        format.any do
          # This prevents an exception from occuring when random search engines try querying
          # for other home page formats
          not_found
        end
      end
    end
  end
  
  # GET /w
  # This allows internal users to access the external homepage.
  def root_external
    if current_user
      @current_user_json = current_user.json_cu
      render layout: 'web'
    else
      # This prevents the '/w' URL from being bookmarked or used when people aren't logged in
      redirect_to '/'
    end
  end

  # GET /pricing
  def pricing
    # Update analytics if logged in
    if current_user
      IntercomEventWorker.perform_async({
        'event_name' => 'viewed-pricing',
        'email' => current_user.email,
        'created_at' => Time.now.to_i
      })
    end

    render layout: 'website'
  end

  # GET /pricing_k12
  def pricing_k12
    redirect_to '/pricing#k12'
  end

  # GET /how-it-works
  def how_it_works
    if current_user
      @current_user_json = current_user.json_cu
    else
      @current_user_json = '{}'
    end

    render layout: 'web'
  end

  # GET /privacy-policy
  def privacy_policy
    render layout: 'website'
  end

  # GET /terms-of-service
  def terms_of_service
    render layout: 'website'
  end

  # GET /help
  def help
    # render help.html.erb
  end

end
