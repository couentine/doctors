class Api::V1::UserSchemas
  include Swagger::Blocks

  #=== USER OUTPUT ATTRIBUTES ===#

  swagger_schema :UserOutputAttributes do
    extend Api::V1::SharedSchemas::CommonDocumentFields

    key :type, :object
    
    property :username do
      key :type, :string
      key :description, 'The url-safe string used to represent this user in urls and other external-facing contexts. Case insensitive.'
      key :example, 'NielArmstrong69'
    end
    property :is_private do
      key :type, :boolean
      key :description, 'True if this user is part of a private email domain. Private email domains restrict the visibility of users ' \
        'with certain email addresses to only other users on their email domain. If this is a private user account, then only the id, ' \
        'username, email hash and image will be visible to users without access to see the domain.'
      key :example, false
    end
    property :email_hash do
      key :type, :string
      key :description, 'A hashed version of the user\'s email address'
      key :example, 'sha256$5c30dbe2195a1a8aa6e2575e8bf33f5a1860370df5b7f07096baffbe26f21e29'
    end
    property :email_salt do
      key :type, :string
      key :description, 'The salt which is appended to the user\'s email address before hashing.'
      key :example, '53304184752c3625a7ce92a2e5de7653'
    end

    property :image_url do
      key :type, :string
      key :format, :url
      key :description, 'URL of this user\'s full-sized avatar image, 500 pixels by 500 pixels'
      key :example, 'https://badgelist.s3.amazonaws.com/u/user/52e20f4c00485d4de3000001/f264877aeb8f8d9afebba9958fe260b7.jpeg'
    end
    property :image_medium_url do
      key :type, :string
      key :format, :url
      key :description, 'URL of this user\'s medium-sized avatar image, 200 pixels by 200 pixels'
      key :example, 'https://badgelist.s3.amazonaws.com/u/user/52e20f4c00485d4de3000001/medium_f264877aeb8f8d9afebba9958fe260b7.jpeg'
    end
    property :image_small_url do
      key :type, :string
      key :format, :url
      key :description, 'URL of this user\'s small-sized avatar image, 50 pixels by 50 pixels'
      key :example, 'https://badgelist.s3.amazonaws.com/u/user/52e20f4c00485d4de3000001/small_f264877aeb8f8d9afebba9958fe260b7.jpeg'
    end

    property :type do
      key :type, :string
      key :enum, [:individual, :group]
      key :description, 'Indicates whether this is an individual user or a group user. Individual users are user accounts which were ' \
        'created using the normal registration process and represent individuals. Group users are proxy users created automatically by ' \
        'the system which represent groups and are used to interact with the API.'
    end
    property :name do
      key :type, :string
      key :description, 'The full name of this user'
      key :example, 'Niel Armstrong'
    end
    
    property :job_title do
      key :type, :string
      key :description, 'Optional profile field indicating the user\'s job title'
      key :example, 'Retired Astronaut'
    end
    property :organization_name do
      key :type, :string
      key :description, 'Optional profile field indicating the user\'s organizational affiliation'
      key :example, 'NASA'
    end
    property :website do
      key :type, :string
      key :description, 'Optional profile field indicating the website of the user or the user\'s organization'
      key :example, 'https://www.nasa.gov'
    end
    property :bio do
      key :type, :string
      key :description, 'Optional profile field indicating biographic details about the user'
      key :example, 'An American astronaut and aeronautical engineer. First person to walk on the Moon.'
    end
    
    property :last_active do
      key :type, :string
      key :format, 'date'
      key :description, 'The date on which this user was last active'
    end

    # property :admin >> FOR NOW THIS IS AN UNDOCUMENTED INTERNAL FIELD

  end

  #=== USER META ===#
  
  swagger_schema :UserMeta do
    key :type, :object

    property :current_user do
      key :type, :object
      
      property :can_see_record do
        key :type, :boolean
        key :description, 'True if the current user is able to see the full contents of the user'
      end
    end
  end

  #=== USER RELATIONSHIPS ===#

  swagger_schema :UserRelationships do
    extend Api::V1::SharedSchemas::RelationshipsList

    key :type, :object

    define_relationship_property :proxy_group, 'If type is `group` then this relationship indicates the group for which this user is ' \
      'a proxy.'
    
    define_relationship_property :groups, 'The groups to which this user belongs, either as a member or as an admin'
    define_relationship_property :portfolios, 'The badge portfolios which this user has created'
  end

end