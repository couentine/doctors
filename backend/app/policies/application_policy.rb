class ApplicationPolicy

  #=== LIST OF ALL AVAILABLE APP PERMISSION SETS ===#
  #
  # These permission sets are used to filter access to specific actions throughout the API based on the permissions granted to the 
  # particular API token being used. 
  # Internal users (accessing the app via the web UI) are granted full access to all permission sets with api_access :internal.
  # External users (accessing via an authentication token) are granted only the permission sets specified on their token record.

  PERMISSION_SETS = {
    'authentication_tokens:read'    => { api_access: [:internal] }, # web UI only
    'authentication_tokens:write'   => { api_access: [:internal] }, # web UI only
    'current_user:read'             => { api_access: [:internal, :external] },
    'current_user:write'            => { api_access: [:internal] }, # web UI only
    'badges:read'                   => { api_access: [:internal, :external] },
    'badges:write'                  => { api_access: [:internal, :external] },
    'domains:read'                  => { api_access: [:internal, :external] },
    'domains:write'                 => { api_access: [:internal] }, # admin only
    'entries:read'                  => { api_access: [:internal, :external] },
    'entries:write'                 => { api_access: [:internal, :external] },
    'group_tags:read'               => { api_access: [:internal, :external] },
    'group_tags:write'              => { api_access: [:internal, :external] },
    'groups:read'                   => { api_access: [:internal, :external] },
    'groups:manage'                 => { api_access: [:internal, :external] },
    'groups:write'                  => { api_access: [:internal, :external] },
    'info_items:read'               => { api_access: [:internal, :external] },
    'pollers:read'                  => { api_access: [:internal, :external] },
    'portfolios:read'               => { api_access: [:internal, :external] },
    'portfolios:review'             => { api_access: [:internal, :external] },
    'portfolios:write'              => { api_access: [:internal, :external] },
    'reports:read'                  => { api_access: [:internal, :external] },
    'reports:write'                 => { api_access: [:internal, :external] },
    'users:read'                    => { api_access: [:internal, :external] },
    'users:write'                   => { api_access: [:internal] }, # admin only
    'users:register'                => { api_access: [:internal, :external] },
    'wikis:read'                    => { api_access: [:internal, :external] },
    'wikis:write'                   => { api_access: [:internal, :external] }
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
