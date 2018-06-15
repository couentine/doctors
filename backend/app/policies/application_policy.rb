class ApplicationPolicy

  # The class instance variables hold the lists of settings for each policy:
  # - decorators = All declared record decorators (items are snake case symbols)
  # - actions = All declared actions (items are hashes)
  # - fields = All declared fields (items are hashes)
  # - roles = All declared roles (items are symbols of role names)
  # - features = All declared features (items are symbols of feature names)
  # - action_map = Hash which maps from action name to the action hash
  
  class << self
    attr_accessor :decorators, :actions, :fields, :relationships, :roles, :features, :action_map, :relationship_map
  end
  
  # The instance variables hold the instantiated policy details for a particular user and record
  # Note: You shouldn't have to override the initialize method. It should work in a generalized way.
  # Other Note: You can use the `expose` parameter to pre-query items which are later consumed in the roles / other blocks.

  attr_reader :current_user, :record, :records, :available_permissions,  :available_features, :expose, :current_user_roles, 
    :current_user_allowed_actions, :current_user_visible_fields, :current_user_editable_fields, :current_user_visible_relationships

  def initialize(current_user, record_or_records, expose: {})
    @current_user = current_user.respond_to?(:api_permissions) ? current_user : UserPermissionsDecorator.new(current_user)
    @available_permissions = @current_user.api_permissions
    @expose = expose

    if (record_or_records.class == Mongoid::Criteria) || (record_or_records.class == Array)
      @records = record_or_records
    elsif (record_or_records.class == Symbol)
      @records = record_or_records
    else
      @record = record_or_records
      if self.class.decorators.present?
        self.class.decorators.each do |decorator_name|
          if decorator_name.class == String
            @record = decorator_name.constantize.new(@record)
          else
            @record = decorator_name.to_s.camelize.constantize.new(@record)
          end
        end
      end

      @available_features = get_available_features
      @current_user_roles = get_current_user_roles
      @current_user_allowed_actions = get_current_user_allowed_actions
      @current_user_visible_fields = get_current_user_visible_fields
      @current_user_editable_fields = get_current_user_editable_fields
      @current_user_visible_relationships = get_current_user_visible_relationships
    end
  end

  #=== API PERMISSIONS ===#
  #
  # These permissions are used to filter access to specific actions throughout the API based on the permissions granted to the 
  # particular API token being used. Permissions are also granted based on whether the user is authenticated or not (user vs. visitor).
  # Any permission sets marked with the `mandatory` option are non-optional and automatically granted to all users / tokens.

  API_ACCESS_TYPES = ATYPES = {
    only_bl_admins: [:web_user], # same as web only (from a permission sets perspective)
    only_web_users: [:web_user],
    only_individual_users: [:web_user, :api_user],
    only_group_users: [:web_user, :api_group], # note that there is no web_group since group tokens are api only
    only_app_users: [:web_user, :api_app], # note that there is no web_app since app tokens are api only
    all_users_no_apps: [:web_user, :api_user, :api_group],
    all_users_no_groups: [:web_user, :api_user, :api_app],
    all_users: [:web_user, :api_user, :api_group, :api_app],
    public_no_bots: [:web_user, :web_visitor, :api_user, :api_group, :api_app],
    public_and_bots: [:web_user, :web_visitor, :api_user, :api_group, :api_app, :api_visitor],
  }

  API_PERMISSIONS = {
    'all:index'                     => { available_to: ATYPES[:public_no_bots], mandatory: true },
    'all:search'                    => { available_to: ATYPES[:public_no_bots], mandatory: true },
    'apps:read'                     => { available_to: ATYPES[:public_and_bots] },
    'apps:manage'                   => { available_to: ATYPES[:only_app_users] },
    'apps:write'                    => { available_to: ATYPES[:only_web_users] },
    'app_group_memberships:read'    => { available_to: ATYPES[:all_users_no_apps] },
    'app_group_memberships:write'   => { available_to: ATYPES[:all_users_no_apps] },
    'app_user_memberships:read'     => { available_to: ATYPES[:all_users_no_groups] },
    'app_user_memberships:write'    => { available_to: ATYPES[:all_users_no_groups] },
    'authentication_tokens:read'    => { available_to: ATYPES[:only_web_users] },
    'authentication_tokens:write'   => { available_to: ATYPES[:only_web_users] },
    'current_user:read'             => { available_to: ATYPES[:only_individual_users] },
    'current_user:write'            => { available_to: ATYPES[:only_web_users] },
    'current_user:manage'           => { available_to: ATYPES[:only_individual_users] },
    'badges:read'                   => { available_to: ATYPES[:public_and_bots] },
    'badges:write'                  => { available_to: ATYPES[:all_users_no_apps] },
    'domains:read'                  => { available_to: ATYPES[:public_no_bots] },
    'domains:write'                 => { available_to: ATYPES[:only_bl_admins] },
    'entries:read'                  => { available_to: ATYPES[:public_no_bots] },
    'entries:write'                 => { available_to: ATYPES[:all_users_no_apps] },
    'group_tags:read'               => { available_to: ATYPES[:public_no_bots] },
    'group_tags:write'              => { available_to: ATYPES[:all_users_no_apps] },
    'groups:read'                   => { available_to: ATYPES[:public_and_bots] },
    'groups:manage'                 => { available_to: ATYPES[:only_group_users] },
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

  #=== RECORD DECORATORS ===#

  # USAGE:
  # 
  # If you need to wrap the @record in one or more decorators during intialization, declare them like this...
  # 
  # record_decorators :app_user_membership_decorator, :app_group_membership_decorator
  #   #==> Wraps first in AppUserMembershipDecorator, then in AppGroupMembershipDecorator
  # 
  # record_decorators 'AppUserMembershipDecorator::UserMembershipDecorator'
  #   #==> Include a string if you need to do fancier syntax. This just turns the string into a constant, then calls new on it.
  # 
  def self.record_decorators(*args)
    @decorators = args
  end

  #=== ACTION POLICIES ===#
  
  # USAGE:
  # 
  # action :show,     
  #   roles: :everyone,
  #   permissions: ['examples:read'],
  #   features: [:bulk_tools]
  # 
  # ==> CREATES INSTANCE METHOD: `show?`
  # 
  # Roles and permissions are required. Features is optional.
  # The `:everyone` symbol is always true, even if the current user has no roles.
  # The `:all_roles` symbol is true if the current user has any of the declared roles.

  def self.action(action_name, options)
    @actions = [] if @actions.nil?
    @action_map = {} if @action_map.nil?

    allowed_roles = options[:roles]
    required_permissions = options[:permissions]
    required_features = options[:features]
    action = {
      name: action_name,
      roles: allowed_roles,
      permissions: required_permissions,
      features: required_features,
    }
    @actions << action
    @action_map[action_name] = action

    method_name = "#{action_name.to_s}?".to_sym
    send :define_method, method_name do
      return (
          (allowed_roles == :everyone) \
          || ((allowed_roles == :all_roles) && @current_user_roles.present?) \
          || (@current_user.present? && @current_user.admin?) \
          || (
            (allowed_roles.class == Array) \
            && (allowed_roles & @current_user_roles).present?
          )
        ) \
        && (required_permissions - @available_permissions).empty? \
        && (
          required_features.blank? \
          || (required_features - @available_features).empty?
        )
    end
  end

  # This is a shortcut to declare all of the standard actions with a single statement.
  # It automatically builds the permissions based on `permission_model`.
  # The roles for index and create are set to everyone, but you must include the roles for show, update and destroy.
  def self.standard_actions(permission_model, show_roles: :everyone, update_roles: nil, destroy_roles: nil)
    permission_string = permission_model.to_s.pluralize

    action :index,
      roles: :everyone,
      permissions: ["all:index", "current_user:read", "#{permission_string}:read"]

    action :show,
      roles: show_roles,
      permissions: ["#{permission_string}:read"]

    action :create,
      roles: :everyone,
      permissions: ["#{permission_string}:write"]

    action :update,
      roles: update_roles,
      permissions: ["#{permission_string}:write"]

    action :destroy,
      roles: destroy_roles,
      permissions: ["#{permission_string}:write"]
  end

  #=== RELATIONSHIP POLICIES ===#
  
  # All relationships result in the creation of a `can_see_relationship_name?` method.
  # 
  # EXAMPLE ON PARENT-SIDE (ClubPolicy):
  # 
  # has_many :memberships,
  #   visible_to: [:admin],
  #   creatable_by: [:owner]
  # 
  # has_many :entries,
  #   policy_model: :item, #==> use this to manually specify the policy model / permission noun
  #   visible_to: [:admin],
  #   creatable_by: [:owner]
  #
  # ==> CREATES ACTION: `entries_index`
  # ==> CREATES ACTION: `create_membership?` w/ permissions = ['clubs:manage', memberships:write']
  # ==> CREATES RELATIONSHIP: `memberships` which shows up in 'visible_relationships' in the meta when visible
  # 
  # EXAMPLE ON CHILD-SIDE (MembershipPolicy):
  # 
  # belongs_to :club,
  #   via: :the_club_id, #==> always required (for explicitness)
  #   visible_to: :everyone,
  #   policy_model: :club, #==> you only need to set this if the policy model is different than the relationship name
  #   read_only: false, #==> set this if the relationship is managed by the system or cannot be set (even on creation)
  #   creation_role: :admin #==> only required if the record can be created from this relationship
  #                              set this to the role which is used to calculate the creation fields when creating via this relationship
  # 
  # ==> CREATES FIELD: `the_club_id`
  #     - The id field is not able to be set when created *by* a club, but can be set when created by other parents
  #     - NOTE: The id field cannot be updated after the record is created. This is a planned limitation because I can't think of
  #       why this would actually be required. It would be an easy feature to add in the future once there's a use case.
  # ==> CREATES RELATIONSHIP: `club` which shows up in 'visible_relationships' in the meta when visible
  # 
  # EXAMPLE FOR MANY TO MANY:
  # 
  # has_and_belongs_to_many :admins,
  #   visible_to: :everyone,
  #   policy_model: :user #==> use this to manually specify the permission noun
  # 
  # ==> CREATES ACTION: `users_index`
  # ==> CREATES RELATIONSHIP: `users` which shows up in 'visible_relationships' in the meta when visible
  # 
  # ROLE KEYWORDS: Accepts all of the same role keywords (everyone, nobody, all roles) as the field / role definitions do.

  def self.has_many(relationship_name, policy_model: nil, visible_to: :everyone, creatable_by: nil)
    @relationships = [] if @relationships.nil?
    @relationship_map = {} if @relationship_map.nil?

    policy_model ||= relationship_name.to_s.singularize.to_sym
    relationship = {
      name: relationship_name,
      policy_model: policy_model,
      type: :has_many,
      visible_to: visible_to, 
      creatable_by: creatable_by,
    }
    @relationships << relationship
    @relationship_map[relationship_name] = relationship

    create_action_name = "create_#{relationship_name.to_s.singularize}".to_sym
    permission_model = self.name.to_s.underscore.gsub(/_policy/, '')
    if permission_model == 'user' 
      # permission is called current_user to highlight that it is singular
      permission_string = permission_model = 'current_user'
    else
      permission_string = permission_model.to_s.pluralize
    end
    child_permission_string = policy_model.to_s.pluralize
    action create_action_name,
      roles: creatable_by,
      permissions: ["#{permission_string}:manage", "#{child_permission_string}:write"]

    index_action_name = "#{relationship_name.to_s}_index".to_sym
    action index_action_name,
      roles: visible_to,
      permissions: ["all:index", "#{child_permission_string}:read"]

    method_name = "can_see_#{relationship_name.to_s}?".to_sym
    required_permissions = ["all:index", "#{child_permission_string}:read"]
    send :define_method, method_name do
      return false if visible_to == :nobody
      return (
        (visible_to == :everyone) \
        || ((visible_to == :all_roles) && @current_user_roles.present?) \
        || (@current_user.present? && @current_user.admin?) \
        || (
          (visible_to.class == Array) \
          && (visible_to & @current_user_roles).present?
        )
      ) && (required_permissions - @available_permissions).empty?
    end
  end

  def self.has_and_belongs_to_many(relationship_name, policy_model: nil, visible_to: :everyone)
    @relationships = [] if @relationships.nil?
    @relationship_map = {} if @relationship_map.nil?

    policy_model ||= relationship_name.to_s.singularize.to_sym
    relationship = {
      name: relationship_name,
      policy_model: policy_model,
      type: :has_and_belongs_to_many,
      visible_to: visible_to,
    }
    @relationships << relationship
    @relationship_map[relationship_name] = relationship

    child_permission_string = policy_model.to_s.pluralize
    index_action_name = "#{relationship_name.to_s}_index".to_sym
    action index_action_name,
      roles: visible_to,
      permissions: ["all:index", "#{child_permission_string}:read"]
    
    define_role_check_method("can_see_#{relationship_name.to_s}?".to_sym, visible_to)
  end

  def self.belongs_to(relationship_name, policy_model: nil, via: nil, visible_to: :everyone, creation_role: nil, read_only: false)
    @relationships = [] if @relationships.nil?
    @relationship_map = {} if @relationship_map.nil?

    relationship = {
      name: relationship_name,
      policy_model: (policy_model || relationship_name),
      type: :belongs_to,
      via: via,
      visible_to: visible_to,
      creation_role: creation_role,
      read_only: false,
    }
    @relationships << relationship
    @relationship_map[relationship_name] = relationship

    field via,
      visible_to: visible_to,
      relationship: relationship_name,
      read_only_relationship: read_only

    define_role_check_method("can_see_#{relationship_name.to_s}?".to_sym, visible_to)
  end

  #=== FIELD POLICIES ===#
  
  # USAGE:
  # 
  # field :name,
  #   visible_to: :everyone, 
  #   editable_by: [:owner]
  # field :user_id,
  #   visible_to: :everyone, 
  #   relationship: :owner,           #==> don't set this directly, if relationship is non-blank, editable_by defaults to nobody
  #   read_only_relationship: true    #==> locks down a relationship field on creation
  # 
  # ==> CREATES INSTANCE METHODS: `can_see_name?`, `can_edit_name?`
  # 
  # The `:everyone` symbol is always true, even if the current user has no roles.
  # The `:all_roles` symbol is true if the current user has any of the declared roles.
  # The `:nobody` symbol is always false, even for Badge List admins. (Intended to be used for non-editable fields.)
  # 
  # OTHER OPTIONS:
  # - The `relationship` property is only used for fields created via the `belongs_to` method. 
  #   When set, it locks down the field so it can only be set on creation (when not created from that relationship) and so it can never
  #   be changed once it is set. Refer to the comments above `self.belongs_to` for more details.
  # - The `secret` option will cause a field not to be made visible to BL admins via override.

  def self.field(field_name, visible_to: :everyone, editable_by: nil, relationship: nil, read_only_relationship: false, secret: false)
    @fields = [] if @fields.nil?

    editable_by = :nobody if relationship.present?
    @fields << {
      name: field_name,
      visible_to: visible_to, 
      editable_by: editable_by,
      relationship: relationship,
      read_only_relationship: read_only_relationship,
      secret: secret,
    }

    define_role_check_method("can_see_#{field_name.to_s}?".to_sym, visible_to, secret)
    define_role_check_method("can_edit_#{field_name.to_s}?".to_sym, editable_by, secret)
  end

  #=== ROLE DEFINITIONS ===#
  
  # USAGE:
  # 
  # role :admin do |current_user, record|
  #   next false if record.disabled?
  #   record.has_admin?(current_user)
  # end
  # 
  # ==> CREATES INSTANCE METHOD: `is_admin?`
  # 
  # Pass a block which evaluates to true using up to two arguments: current_user, record, policy
  # The third argument (policy) can usually be skipped. It is designed to help reuse other role definitions.
  # Remember to use the `next` keyword in place of the `return` keyword if needed.

  def self.role(role_name, &block)
    @roles = [] if @roles.nil?

    @roles << role_name

    method_name = "is_#{role_name.to_s}?".to_sym
    send :define_method, method_name do
      return (block.call(@current_user, @record, self)) ? true : false
    end
  end

  #=== FEATURE DEFINITIONS ===#
  
  # USAGE:
  # 
  # feature :bulk_tools do |record|
  #   record.group.has?(:bulk_tools)
  # end
  # 
  # ==> CREATES INSTANCE METHOD: `has_bulk_tools?`
  # 
  # Pass a block which evaluates to true using the @record.
  # NOTE: To keep things focused, features do *not* depend on the current user. If some sort of functionality depends on a combination
  # of a feature AND the user's permission, break it into two separate pieces: a role and a feature.
  # 
  # Remember to use the `next` keyword in place of the `return` keyword if needed.

  def self.feature(feature_name, &block)
    @features = [] if @features.nil?

    @features << feature_name

    method_name = "has_#{feature_name.to_s}?".to_sym
    send :define_method, method_name do
      return (block.call(@record)) ? true : false
    end
  end

  #=== METADATA ===#

  def meta
    meta = {
      current_user: {
        roles: @current_user_roles,
        allowed_actions: @current_user_allowed_actions,
        editable_fields: @current_user_editable_fields,
        visible_relationships: @current_user_visible_relationships,
      },
    }
    meta[:available_features] = @available_features if self.class.features.present?

    return meta
  end

  # Call this only when instantiating with a list of records.
  # Returns a hash with keys being the record id strings and values being the meta for each item in the list.
  def policy_index
    policy_index_hash = {}

    @records.each do |record|
      policy_index_hash[record.id.to_s] = self.class.new(@current_user, record, expose: @expose)
    end

    return policy_index_hash
  end

  # Do not override this, it is generalized and reusable.
  # The default version excludes the index and create actions since they are not linked to an individual record
  # Exclude `:all_indexes` in order to exclude any action which ends with '_index'.
  def get_current_user_allowed_actions(exclude: [:show, :index, :create, :all_indexes])
    return (self.class.actions || []).select do |action|
      !exclude.include?(action[:name]) \
        && (!exclude.include?(:all_indexes) || !action[:name].to_s.ends_with?('_index')) \
        && self.send("#{action[:name].to_s}?")
    end.map do |action|
      action[:name]
    end
  end

  # Do not override this, it is generalized and reusable.
  def get_current_user_visible_fields
    return (self.class.fields || []).select do |field|
      self.send("can_see_#{field[:name].to_s}?")
    end.map do |field|
      field[:name]
    end
  end

  # Do not override this, it is generalized and reusable.
  def get_current_user_editable_fields
    return (self.class.fields || []).select do |field|
      self.send("can_edit_#{field[:name].to_s}?")
    end.map do |field|
      field[:name]
    end
  end

  # Do not override this, it is generalized and reusable.
  def get_current_user_visible_relationships
    return (self.class.relationships || []).select do |relationship|
      self.send("can_see_#{relationship[:name].to_s}?")
    end.map do |relationship|
      relationship[:name]
    end
  end

  # Do not override this, it is generalized and reusable.
  # This returns a list of all fields which are editable upon new record creation.
  # You must specify the relationship source (so that that relationship field can be blocked out).
  # Note: This means that *all* creatable models need at least one belongs_to relationship, this can always just be 'creator'.
  #   Except for user. User is special... so you can just pass `:self` as the parent relationship.
  def self.get_creation_fields_for(parent_relationship)
    if @relationship_map.has_key?(parent_relationship)
      creation_role = @relationship_map[parent_relationship][:creation_role]
      
      if creation_role.blank?
        raise ArgumentError.new("Creation role for #{parent_relationship} is missing in #{self.name}")
      end
    else
      if (self == UserPolicy) && (parent_relationship == :self)
        creation_role = :self
      else
        raise ArgumentError.new("Cannot find a relationship called #{parent_relationship} in #{self.name}") 
      end
    end

    return (@fields || []).select do |field|
      (field[:editable_by] == :all_roles) \
      || ((field[:editable_by].class == Array) && field[:editable_by].include?(creation_role)) \
      || (field[:relationship].present? && (field[:relationship] != parent_relationship) && (field[:read_only_relationship] != true))
    end.map do |field|
      field[:name]
    end
  end

  # Do not override this, it is generalized and reusable.
  def get_current_user_roles
    return (self.class.roles || []).select do |role_name|
      self.send("is_#{role_name.to_s}?")
    end
  end

  # Do not override this, it is generalized and reusable.
  def get_available_features
    return (self.class.features || []).select do |feature_name|
      self.send("has_#{feature_name.to_s}?")
    end
  end

  # This is a general purpose utility method which can be called on any model policy or on the application policy itself.
  # It is designed to assist the swagger docs classes in easily deterining the permissions required for a particular action.
  # 
  # USAGE:
  # 
  # PortfolioPolicy.get_action_permissions(:show)
  #   #==> Returns list of permissions required for `show` action
  # 
  # UserPolicy.get_action_permissions(:authentication_token, :index)
  #   #==> Returns permissions for `authentication_tokens_index`
  # 
  # UserPolicy.get_action_permissions(:authentication_token, :create)
  #   #==> Returns permissions for `create_authentication_token`
  # 
  # ApplicationPolicy.get_action_permissions(:badge, :portfolio, :index)
  #   #==> Returns permissions for `portfolios_index` on BadgePolicy
  # 
  # ApplicationPolicy.get_action_permissions(:group, :update)
  #   #==> Returns permissions for `update` on GroupPolicy
  # 
  # Note: The actions `:get` and `:delete` will automatically be converted to `:show` and `:destroy`.
  # 
  def self.get_action_permissions(*args)
    raise ArgumentError.new('get_action_permissions requires at least 1 argument') if args.count == 0
    raise ArgumentError.new('get_action_permissions supports no more than 3 arguments') if args.count > 3

    if self == ApplicationPolicy
      raise ArgumentError.new('Calling get_action_permissions on ApplicationPolicy supports only 2 or 3 arguments') if args.count == 1
      return "#{args.first.to_s.camelize}Policy".constantize.get_action_permissions(*args[1..100])
    else
      raise ArgumentError.new('Calling get_action_permissions on a model policy supports only 1 or 2 arguments') if args.count == 3
      
      action = args.last
      action = :show if action == :get
      action = :destroy if action == :delete

      if args.count == 2
        if action == :create
          full_action_name = "create_#{args.first.to_s}"
        else
          full_action_name = "#{args.first.to_s.pluralize}_#{action.to_s}"
        end
      else
        full_action_name = action.to_s
      end

      if @action_map.has_key? full_action_name.to_sym
        return @action_map[full_action_name.to_sym][:permissions]
      else
        raise ArgumentError.new("Cannot find an action called '#{full_action_name}' in #{name}")
      end
    end
  end

  #=== SCOPE ===#

  def scope
    Pundit.policy_scope!(current_user, record.class)
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

  #=== PRIVATE METHODS ===#

  def self.define_role_check_method(method_name, matching_roles, secret = false)
    send :define_method, method_name do
      return false if matching_roles == :nobody
      return (matching_roles == :everyone) \
        || ((matching_roles == :all_roles) && @current_user_roles.present?) \
        || (@current_user.present? && @current_user.admin? && !secret) \
        || (
          (matching_roles.class == Array) \
          && (matching_roles & @current_user_roles).present?
        )
    end
  end
end
