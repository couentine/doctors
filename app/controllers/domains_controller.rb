class DomainsController < ApplicationController

  # === FILTERS === #

  prepend_before_action :find_domain, only: [:show, :edit, :update, :destroy]
  before_action :authenticate_user!
  before_action :badge_list_admin, only: [:index, :new, :edit, :create, :update, :destroy]
  before_action :can_see_domain, only: [:show]
  before_action :set_form_constants, only: [:new, :edit, :create, :update]

  # === CONSTANTS === #

  PERMITTED_PARAMS = [:url, :is_private]

  IS_PRIVATE_OPTIONS = [
    ['Private', true],
    ['Not Private', false]
  ]

  # === RESTFUL ACTIONS === #

  # GET /domains
  # GET /domains.json
  # Accepts page parameters: page, page_size, sort_by, sort_order
  def index
    # Grab the current page of domains
    @page = params[:page] || 1
    @page_size = params[:page_size] || APP_CONFIG['page_size_normal']
    @sort_by = params[:sort_by] || 'url'
    @sort_order = params[:sort_order] || 'asc'
    
    @domains = Domain.order_by("#{@sort_by} #{@sort_order}").page(@page).per(@page_size)

    respond_to do |format|
      format.html # index.html.erb
      format.json { render json: @domains, filter_user: current_user }
    end
  end

  # GET /domain/1
  # GET /domain/1.json
  def show
    # Initialize the translated properties
    load_translated_properties

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @domain, filter_user: current_user }
    end
  end

  # GET /domains/new
  def new
    @domain = Domain.new
    @visible_to_domain_urls, @can_see_domain_urls, @non_private_user_usernames = '', '', ''

    respond_to do |format|
      format.html # new.html.erb
    end
  end

  # GET /domain/1/edit
  def edit
    # Initialize the translated properties
    load_translated_properties
    
    respond_to do |format|
      format.html # edit.html.erb
    end
  end

  # POST /domains
  # POST /domains.json
  # Accepts special params: owner_username, visible_to_domain_urls, non_private_user_usernames
  def create
    # Build the translated properties
    build_translated_properties

    # Create the domain
    @domain = Domain.new(domain_params)
    @domain.owner = @owner
    @domain.non_private_domain_user_ids = @non_private_domain_user_ids

    respond_to do |format|
      if @domain.save && @domain.update_visible_to_domains(@visible_to_domains)
        format.html { redirect_to @domain, notice: 'Domain was successfully created.' }
        format.json { render json: @domain, status: :created, location: @domain,
          filter_user: current_user }
      else
        @can_see_domain_urls = @domain.can_see_domain_urls.join(', ')

        format.html { render action: "new" }
        format.json { render json: @domain.errors, status: :unprocessable_entity }
      end
    end
  end

  # PUT /domain/1
  # PUT /domain/1.json
  def update
    # Build the translated properties
    build_translated_properties

    # Update the domain
    @domain.update_attributes(domain_params)
    @domain.owner = @owner
    @domain.non_private_domain_user_ids = @non_private_domain_user_ids

    respond_to do |format|
      if @domain.save && @domain.update_visible_to_domains(@visible_to_domains)
        format.html { redirect_to @domain, notice: 'Domain was successfully updated.' }
        format.json { head :no_content }
      else
        @can_see_domain_urls = @domain.can_see_domain_urls.join(', ')

        format.html { render action: "edit" }
        format.json { render json: @domain.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /domain/1
  # DELETE /domain/1.json
  def destroy
    @domain.destroy

    respond_to do |format|
      format.html { redirect_to '/', notice: 'The domain has been deleted.' }
      format.json { head :no_content }
    end
  end

private

  def find_domain
    @domain = Domain.find(params[:id] || params[:domain_id]) || not_found
    @owner = @domain.owner
    @badge_list_admin = current_user && current_user.admin?
    @current_user_is_owner = current_user && (current_user.id == @owner.id)
    @current_user_is_member = @current_user_is_owner \
      || (current_user && (current_user.domain_id == @domain.id))
    @can_see_domain = @badge_list_admin || @current_user_is_member \
      || (current_user && @domain.visible_to_domain_urls.include?(current_user.email_domain))
  end

  def badge_list_admin
    unless current_user && current_user.admin?
      redirect_to '/'
    end  
  end

  def can_see_domain
    unless @can_see_domain
      redirect_to '/'
    end  
  end

  def set_form_constants
    @domain_is_private_options = IS_PRIVATE_OPTIONS
  end

  # Called from show and edit
  def load_translated_properties
    @owner_username = (@domain.owner || current_user).username
    @visible_to_domain_urls = @domain.visible_to_domain_urls.join(', ')
    @can_see_domain_urls = @domain.can_see_domain_urls.join(', ')
    @non_private_user_usernames = @domain.non_private_user_usernames.join(', ')
  end

  # Called from create and update
  def build_translated_properties
    @owner_username = params[:owner_username]
    @visible_to_domain_urls = params[:visible_to_domain_urls]
    @non_private_user_usernames = params[:non_private_user_usernames]

    # Translate owner into user record
    @owner = (User.find(@owner_username) rescue nil) || current_user
    
    # Translate visible domains into array of domain records
    if @visible_to_domain_urls.blank?
      @visible_to_domains = []
    else
      visible_to_domain_url_list = \
        @visible_to_domain_urls.downcase.split(',').map{ |url| url.strip }
      @visible_to_domains = \
        Domain.where(:url.in => visible_to_domain_url_list).map{ |domain| domain }
    end

    # Translate non private users into a cleaned up array of user ids
    if @non_private_user_usernames.blank?
      @non_private_domain_user_ids = []
    else
      non_private_user_username_list = \
        @non_private_user_usernames.downcase.split(',').map{ |username| username.strip }
      @non_private_domain_user_ids = \
        User.where(:username.in => non_private_user_username_list).map{ |user| user.id }
    end
  end

  def domain_params
    params.require(:domain).permit(PERMITTED_PARAMS)
  end

end