class Api::V1::Schemas::SharedSchemas
  include Swagger::Blocks

  #=== LINKS OBJECT ===#

  swagger_schema :LinksObject do
    key :type, :object
    
    property :self do
      key :type, :string
      key :format, :url
      key :description, 'Relative URL of this item in the API'
      key :example, "/api/v1/model_name/841b90e775421f5205bf70a0"
    end
    property :self_web do
      key :type, :string
      key :format, :url
      key :description, 'Full URL of this item in the web app'
      key :example, "https://www.badgelist.com/model_path/in_web_ui/841b90e775421f5205bf70a0"
    end
  end

  #=== ROOT META OBJECT (BASE) ===#

  swagger_schema :RootMetaObject do
    key :type, :object

    property :authentication_method do
      key :type, :string
      key :enum, [:token, :session, :none]
      key :description, 'How the current request is authenticated. (Some actions are available without authentication.)'
    end
    property :access_method do
      key :type, :string
      key :enum, [:api, :web]
      key :description, 'How the API is being accessed. Always equals `api` (unless being used from within the Badge List web app).'
    end
  end

  #=== ROOT META OBJECT (WITH PERMISSIONS SETS) ===#

  swagger_schema :RootMetaObjectWithPermissions do
    key :type, :object

    property :authentication_method do
      key :type, :string
      key :enum, [:token, :session, :none]
      key :description, 'How the current request is authenticated. (Some actions are available without authentication.)'
    end
    property :access_method do
      key :type, :string
      key :enum, [:api, :web]
      key :description, 'How the API is being accessed. Always equals `api` (unless being used from within the Badge List web app).'
    end
    property :permissions do
      key :type, :array
      key :items, { type: :string }
      key :description, 'List of permissions available for the current request'
    end
  end

  #=== ROOT META OBJECT (WITH PAGINATION) ===#

  swagger_schema :RootMetaObjectWithPagination do
    key :type, :object

    property :authentication_method do
      key :type, :string
      key :enum, [:token, :session, :none]
      key :description, 'How the current request is authenticated. (Some actions are available without authentication.)'
    end
    property :access_method do
      key :type, :string
      key :enum, [:api, :web]
      key :description, 'How the API is being accessed. Always equals `api` (unless being used from within the Badge List web app).'
    end

    property :page do
      key :type, :object
      
      property :number do
        key :type, :integer
        key :description, 'The current page of results'
      end
      property :size do
        key :type, :integer
        key :description, 'The maximum number of items per page of results'
      end
      property :prev do
        key :type, :integer
        key :description, 'The page number of the previous page of results if there is one'
      end
      property :next do
        key :type, :integer
        key :description, 'The page number of the next page of results if there is one'
      end
      property :last do
        key :type, :integer
        key :description, 'The page number of the final page of results'
      end
    end
    property :sort do
      key :type, :string
      key :description, 'Indicates the sort which was used to order the results'
    end
    property :filter do
      key :type, :object
      key :description, 'Indicates the filter settings which were used to filter the results'
    end
  end

  #=== ROOT JSON API OBJECT ===#

  swagger_schema :JsonApiObject do
    key :type, :object

    property :version do
      key :type, :string
      key :enum, ['1.0']
    end
  end
  
end