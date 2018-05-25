class ApplicationPolicy

  #=== LIST OF ALL AVAILABLE APP PERMISSION SETS ===#
  #
  # These permission sets are used to filter access to specific actions throughout the API based on the permissions granted to the 
  # particular API token being used. Permissions are also granted based on whether the user is authenticated or not (user vs. visitor).
  # Any permission sets marked with the `mandatory` option are non-optional and automatically granted to all users / tokens.

  API_ACCESS_TYPES = ATYPES = {
    only_bl_admins: [:web_user], # same as web only (from a permission sets perspective)
    only_web_users: [:web_user],
    only_individual_users: [:web_user, :api_user],
    only_group_users: [:api_group], # note that there is no web_group since group tokens are api only
    only_app_users: [:api_app], # note that there is no web_app since app tokens are api only
    all_users_no_apps: [:web_user, :api_user, :api_group],
    all_users: [:web_user, :api_user, :api_group, :api_app],
    public_no_bots: [:web_user, :web_visitor, :api_user, :api_group, :api_app],
    public_and_bots: [:web_user, :web_visitor, :api_user, :api_group, :api_app, :api_visitor],
  }
  PERMISSION_SETS = {
    'all:index'                     => { available_to: ATYPES[:public_no_bots], mandatory: true },
    'all:search'                    => { available_to: ATYPES[:public_no_bots], mandatory: true },
    'authentication_tokens:read'    => { available_to: ATYPES[:only_web_users] },
    'authentication_tokens:write'   => { available_to: ATYPES[:only_web_users] },
    'current_user:read'             => { available_to: ATYPES[:only_individual_users] },
    'current_user:write'            => { available_to: ATYPES[:only_web_users] },
    'badges:read'                   => { available_to: ATYPES[:public_and_bots] },
    'badges:write'                  => { available_to: ATYPES[:all_users_no_apps] },
    'domains:read'                  => { available_to: ATYPES[:public_no_bots] },
    'domains:write'                 => { available_to: ATYPES[:only_bl_admins] },
    'entries:read'                  => { available_to: ATYPES[:public_no_bots] },
    'entries:write'                 => { available_to: ATYPES[:all_users_no_apps] },
    'group_tags:read'               => { available_to: ATYPES[:public_no_bots] },
    'group_tags:write'              => { available_to: ATYPES[:all_users_no_apps] },
    'groups:read'                   => { available_to: ATYPES[:public_and_bots] },
    'groups:manage'                 => { available_to: ATYPES[:all_users_no_apps] },
    'groups:write'                  => { available_to: ATYPES[:all_users_no_apps] },
    'info_items:read'               => { available_to: ATYPES[:all_users] },
    'pollers:read'                  => { available_to: ATYPES[:all_users] },
    'portfolios:read'               => { available_to: ATYPES[:public_and_bots] },
    'portfolios:review'             => { available_to: ATYPES[:all_users_no_apps] },
    'portfolios:write'              => { available_to: ATYPES[:all_users_no_apps] },
    'reports:read'                  => { available_to: ATYPES[:all_users_no_apps] },
    'reports:write'                 => { available_to: ATYPES[:all_users_no_apps] },
    'users:read'                    => { available_to: ATYPES[:public_and_bots] },
    'users:write'                   => { available_to: ATYPES[:only_web_users] },
    'users:register'                => { available_to: ATYPES[:all_users] },
    'wikis:read'                    => { available_to: ATYPES[:public_no_bots] },
    'wikis:write'                   => { available_to: ATYPES[:all_users_no_apps] },
  }

  #=== PUNDIT POLICY DEFINITION ===#

  attr_reader :current_user, :record, :records

  def initialize(current_user, record_or_records)
    @current_user = current_user
    if (record_or_records.class == Mongoid::Criteria)
      @records = record_or_records
    else
      @record = record_or_records
    end
  end

  def index?
    false
  end

  def show?
    scope.where(:id => record.id).exists?
  end

  def create?
    false
  end

  def new?
    create?
  end

  def update?
    false
  end

  def edit?
    update?
  end

  def destroy?
    false
  end

  def scope
    Pundit.policy_scope!(current_user, record.class)
  end

  # Call this only when instantiating with a list of records.
  # Returns a hash with keys being the record id strings and values being the meta for each item in the list.
  def meta_index
    meta_index_hash = {}

    @records.each do |record|
      meta_index_hash[record.id.to_s] = self.class.new(@current_user, record).meta
    end

    return meta_index_hash
  end

  class Scope
    attr_reader :current_user, :scope

    def initialize(current_user, scope)
      @current_user = current_user
      @scope = scope
    end

    def resolve
      scope
    end
  end
end
