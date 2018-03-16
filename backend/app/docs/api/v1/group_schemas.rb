class Api::V1::GroupSchemas
  include Swagger::Blocks

  #=== GROUP ATTRIBUTES ===#

  swagger_schema :GroupAttributes do
    extend Api::V1::SharedSchemas::CommonDocumentFields
    
    property :name do
      key :type, :string
      key :description, 'Display name of the group'
    end
    property :description do
      key :type, :string
      key :description, 'Short summary text describing the group and its purpose'
    end
    
    property :location do
      key :type, :string
      key :description, 'Free text field which is intended to describe the location of the group'
    end
    property :type do
      key :type, :string
      key :enum, [:free, :paid]
      key :description, 'Indicates whether or not this is a paid group'
    end
    property :color do
      key :type, :string
      key :enum, [:red, :pink, :purple, :deep_purple, :indigo, :blue, :light_blue, :cyan, :teal, :green, :light_green, :lime, :yellow, 
        :amber, :orange, :deep_orange, :brown, :grey, :blue_grey]
      key :description, 'The primary color used for the visual styling of the group. The actual colors used come from the ' \
        'Google Material Design Color Palette.'
    end
    
    property :member_count do
      key :type, :integer
      key :description, 'The number of group members'
    end
    property :admin_count do
      key :type, :integer
      key :description, 'The number of group admins'
    end
    property :total_user_count do
      key :type, :integer
      key :description, 'The number of total users in the group (including both members and admins)'
    end
    property :badge_count do
      key :type, :integer
      key :description, 'The number of badges in the group'
    end

    property :image_url do
      key :type, :string
      key :format, :url
      key :description, 'URL of the full-sized group image, 500 pixels wide and/or long'
    end
    property :image_medium_url do
      key :type, :string
      key :format, :url
      key :description, 'URL of the resized group image, 200 pixels wide and/or long'
    end
    property :image_small_url do
      key :type, :string
      key :format, :url
      key :description, 'URL of the resized group image, 50 pixels wide and/or long'
    end

  end

  #=== GROUP META ===#
  
  swagger_schema :GroupMeta do
    property :current_user do
      key :type, :object

      property :can_see_record do
        key :type, :boolean
        key :description, 'True if the current user is able to see the full contents of the group'
      end
      property :can_edit_record do
        key :type, :boolean
        key :description, 'True if the current user is able to edit the group'
      end
      property :can_see_members do
        key :type, :boolean
        key :description, 'True if the current user is able to see the group members list'
      end
      property :can_see_admins do
        key :type, :boolean
        key :description, 'True if the current user is able to see the group admins list'
      end
      property :can_see_group_tags do
        key :type, :boolean
        key :description, 'True if the current user is able to see the group tags'
      end
      property :can_copy_badges do
        key :type, :boolean
        key :description, 'True if the current user is able to copy badges from the group to another group'
      end
      property :can_assign_group_tags do
        key :type, :boolean
        key :description, 'True if the current user is able to assign users and badges to a group tag'
      end
      property :can_create_group_tags do
        key :type, :boolean
        key :description, 'True if the current user is able to create new group tags'
      end
      property :is_member do
        key :type, :boolean
        key :description, 'True if the current user is a member of this group'
      end
      property :is_admin do
        key :type, :boolean
        key :description, 'True if the current user is an admin of this group'
      end      
    end
  end

  #=== GROUP RELATIONSHIPS ===#

  # NONE YET (These will be added later once there is a user serializer)

end