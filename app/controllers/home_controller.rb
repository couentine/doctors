class HomeController < ApplicationController

  # GET /?gp=1&bp=1&query=group
  # This renders the appropriate root layout based on whether user is signed in
  def root
    if current_user
      @user = current_user
      @page_size = APP_CONFIG['page_size_small']
      @query = params[:query] || 'all'
      @badge_count = @user.expert_badge_ids.count # doesn't result in a query
      
      flash[:notice] = 'This is an important but non-critical message.'
      flash[:success] = 'This is longer'
      flash[:warning] = 'OMG! Something huge happened. It\'s bad.'

      if @query.in? ['all', 'group']
        @groups_current_page = (params[:gp] || 1).to_i
        @groups_hash = @user.groups(false).asc(:name).page(@groups_current_page).per(@page_size)\
            .map do |group| 
          j = group.as_json
          j['member_type'] = @user.member_type_of(group.id).to_s # = ['admin', 'member', 'none']
          j
        end
        
        if @user.groups(false).count > (@page_size * @groups_current_page)
          @groups_next_page = @groups_current_page + 1
        else
          @groups_next_page = nil
        end
      end
      
      if @query.in? ['all', 'badge']
        # FIXME
      end

      respond_to do |format|
        format.html { render template: 'home/root_internal', layout: 'app' }
        format.json do
          if @query == 'group'
            render json: { next_page: @groups_next_page, groups: @groups_hash }
          elsif @query == 'badge'
            render json: nil # FIXME
          else
            render json: nil
          end
        end
      end
    else
      render template: 'home/root_external', layout: 'website'
    end
  end
  
  # GET /w
  # This allows internal users to access the external homepage.
  def root_external
    render layout: 'website'
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
