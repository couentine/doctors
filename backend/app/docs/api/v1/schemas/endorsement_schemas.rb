class Api::V1::Schemas::EndorsementSchemas
  include Swagger::Blocks

  #=== ENDORSEMENT INPUT ATTRIBUTES ===#

  swagger_schema :EndorsementInputAttributes do
    key :type, :object

    property :email do
      key :type, :string
      key :format, :email
      key :description, 'The email address of the person to endorse'
      key :required, true
      key :example, 'a.einstein@example.com'
    end

    property :summary do
      key :type, :string
      key :description, "The summary text which is used as the title of the endorsement. If this is longer than " \
        "#{Entry::MAX_SUMMARY_LENGTH} characters it is automatically clipped."
      key :required, true
      key :max_length, Entry::MAX_SUMMARY_LENGTH
      key :example, "Albert's paper is most impressive"
    end

    property :body do
      key :type, :string
      key :format, :html
      key :description, 'The optional (but encouraged) html-formatted text used as the body of the endorsement. The html is ' \
        'sanitized according to an extensive whitelist of allowed html tags. Headers, paragraphs, lists, anchors and images are all ' \
        'allowed. In general we encourage including as much context as possible while making the endorsement formatting easy to scan ' \
        'and as aesthetically pleasing as possible.'
      key :example, "<p>The only thing which needs to be investigated with regard to <em>the State of the Ether in a Magnetic Field</em> " \
        "is my own shock at the depth and quality of Albert's thought work.</p><p>This badge is definitely well earned. " \
        "<strong>Congratulations</strong>!</p>"
    end

  end

  #=== ENDORSEMENT RESULT ATTRIBUTES ===#

  swagger_schema :EndorsementResultAttributes do
    key :type, :object

    property :index do
      key :type, :integer
      key :description, 'The zero-based index of the corresponding item in the request data array. Included for convenience, ' \
        'this will always be equal to the index in the results array as well.'
      key :example, 0
    end

    property :type do
      key :type, :string
      key :enum, [:new_user, :new_member, :new_expert, :existing_seeker, :existing_holder, :error]
      key :description, 'The result of the processing of the corresponding endorsement item'
      key :example, 'new_user'
    end

    property :success do
      key :type, :boolean
      key :description, 'True if the `type` was not equal to `error`'
      key :example, true
    end

    property :error_message do
      key :type, :string
      key :description, 'If `type` was error then this will contain a user-facing error message. Otherwise this will be null.'
    end

  end

end