class Api::V1::SerializableDocument < JSONAPI::Serializable::Resource
  extend JSONAPI::Serializable::Resource::ConditionalFields

  # The class instance variables hold the lists settings for each serializer:
  # - fields = Array of all declared fields (items are hashes)
  # - non_computed_source_fields = Array of all of the source fields which are used directly or renamed (items are symbols)
  # - rendered_field_name_for = Hash with keys for each non_computed_source_fields, values equal to rendered field keys
  
  class << self
    attr_accessor :fields, :non_computed_source_fields, :rendered_field_name_for
  end
    
  #=== STANDARD FIELDS ===#
  
  id { @object.id.to_s }

  attribute :created_at do
    @object.created_at.iso8601 if @object.created_at
  end

  attribute :updated_at do
    @object.updated_at.iso8601 if @object.updated_at
  end

  #=== STANDARD META ===#

  # NOTE: This is generalized and reusable.
  # You should only need to override it if you want to generate non-standard meta (or skip the meta altogether).

  meta do
    meta = (@policy ||= @policy_index[@object.id.to_s]).meta
    
    meta[:current_user][:editable_fields] = meta[:current_user][:editable_fields].select do |source_field_name|
      self.class.non_computed_source_fields.include? source_field_name
    end.map do |source_field_name|
      self.class.rendered_field_name_for[source_field_name]
    end

    meta
  end

  #=== CUSTOM FIELDS ===#

  # USAGE:
  # 
  # field :normal_non_renamed_field
  # field :renamed_name, from: :name
  # field :user_id, convert: :to_s #==> NOTE: A convert to string is AUTOMATICALLY added for fields ending w/ '_id'
  # field :group_id, from: :proxy_group_id, convert: :to_s
  # field :full_name, from: [:first_name, :last_name] do |record|
  #   "#{record.first_name} #{record.last_name}"
  # end
  # field :group_count, from: :groups do |record| #==> from can be a relationship name too (if there's a block)
  #   record.group_ids.count
  # end
  # 
  # This syntax will conditionally include the field depending on the visibility of the field in the policy.
  # It requires inclusion of a @policy variable which responds to `current_user_visible_fields`.
  # If the field in the serialized output is different than the field key on the model, specify the model key with the `from`
  # 
  # If you want to convert a field value by calling a simple method on the field, use the `convert:` keyword.
  # This will call the passed method on the field value, but will not count it as a calculated field.
  # Note: This is helpful because calculated fields are automatically filtered out of the editable fields list.
  # 
  # For calculated fields, include a block and also set the from field to a single key or a list of keys. 
  # If you leave out the from field, the from field is assumed to be the same as the field_name.
  # The calculated field will only be included if all of the from fields are visible on the model policy.

  def self.field(field_name, from: nil, convert: nil, &block)
    @fields = [] if @fields.nil?
    @non_computed_source_fields = [] if @non_computed_source_fields.nil?
    @rendered_field_name_for = {} if @rendered_field_name_for.nil?
    convert ||= :to_s if field_name.to_s.ends_with?('_id')

    # Declare the attributes using the JSON API RB syntax
    if block.present?
      field_type = :calculated
      source_field_name = nil
      if from.blank?
        required_fields = [field_name]
      else
        required_fields = (from.class == Array) ? from : [from]
      end

      attribute field_name, 
        if: -> do
          (required_fields \
            - (@policy || @policy_index[@object.id.to_s]).current_user_visible_fields \
            - (@policy || @policy_index[@object.id.to_s]).current_user_visible_relationships
          ).empty?
        end do
          block.call(@object)
        end
    elsif from.present?
      field_type = :renamed
      source_field_name = from

      attribute field_name, 
        if: -> do
          (@policy || @policy_index[@object.id.to_s]).current_user_visible_fields.include?(from)
        end do
          if convert.present?
            if @object.send(from).present?
              @object.send(from).send(convert)
            else
              nil
            end
          else
            @object.send(from)
          end
        end
    else
      field_type = :direct
      source_field_name = field_name

      if convert.present?
        attribute field_name,
          if: -> do
            (@policy || @policy_index[@object.id.to_s]).current_user_visible_fields.include?(field_name)
          end do
            if @object.send(field_name).present?
              @object.send(field_name).send(convert)
            else
              nil
            end
          end
      else
        attribute field_name,
          if: -> do
            (@policy || @policy_index[@object.id.to_s]).current_user_visible_fields.include?(field_name)
          end
      end
    end

    # Set the class instance variables
    @fields << {
      name: field_name,
      from: source_field_name,
      type: field_type,
    }
    if field_type != :computed
      # Note: We ignore computed fields since the source fields stuff only exists in order to rebuild the list of editable fields.
      # The various sources for computed fields shouldn't be included in the list of editable fields since edits can't map backwards.
      @non_computed_source_fields << source_field_name
      @rendered_field_name_for[source_field_name] = field_name
    end
  end

  #=== STANDARD SELF LINKS ===#

  # USAGE:
  # 
  # self_links
  # 
  # This adds the standard self and self_web links. There are no options,

  def self.self_links
    object_path = @type_val.to_s.pluralize

    link :self do
      "/api/v1/#{object_path}/#{@object.id.to_s}"
    end
    link :self_web do
      @object.full_url
    end
  end

  #=== RELATIONSHIPS ===#

  # USAGE EXAMPLE (On Serializable Badge):
  # 
  # relationships :group, :portfolios, [:creator, :user, :the_creator_id]
  #   #==> `:group` ==> SINGULAR ==> Declares group = "/api/v1/groups/#{@object.group_id.to_s}"
  #   #==> `:portfolios` ==> PLURAL ==> Declares portfolios = "/api/v1/badges/#{@object.id.to_s}/portfolios"
  #   #==> Last Item ==> ARRAY ==> Declares creator = "/api/v1/users/#{@object.the_creator_id.to_s}"
  # 
  # Note: This automatically adds conditional logic which hides the relationships if they are not visible

  def self.relationships(*args)
    object_path = @type_val.to_s.pluralize

    args.each do |relationship|
      if relationship.class == Array
        raise ArgumentError.new('Array-based relationship definitions must have exactly three items') if relationship.count != 3
        if relationship.first.to_s.pluralize == relationship.first.to_s
          raise ArgumentError.new('Array-based relationship must be singular, make sure first item in array is singular') 
        end

        relationship_name = relationship[0]
        relationship_object_path = relationship[1].to_s.pluralize
        relationship_id_field = relationship[2].to_s

        # ARRAY = BELONGS TO WITH CUSTOM NAMES
        belongs_to relationship_name,
          if: -> do
            (@policy || @policy_index[@object.id.to_s]).current_user_visible_relationships.include?(relationship_name) \
            && @object.send(relationship_id_field).present?
          end do
            link :self do
              "/api/v1/#{relationship_object_path}/" + @object.send(relationship_id_field).to_s
            end
          end
      elsif relationship.to_s.pluralize == relationship.to_s
        # PLURAL = HAS MANY
        has_many relationship,
          if: -> do
            (@policy || @policy_index[@object.id.to_s]).current_user_visible_relationships.include?(relationship)
          end do
          link :self do
            "/api/v1/#{object_path}/#{@object.id.to_s}/#{relationship}"
          end
        end
      else
        # SINGULAR = BELONGS TO
        belongs_to relationship, 
          if: -> do
            (@policy || @policy_index[@object.id.to_s]).current_user_visible_relationships.include?(relationship) \
            && @object.send("#{relationship}_id").present?
          end do
            link :self do
              "/api/v1/#{relationship.to_s.pluralize}/" + @object.send("#{relationship}_id").to_s
            end
          end
      end
    end
  end

end