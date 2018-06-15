class Api::V1::Schemas::UserSchemas < Api::V1::Schemas::ApiSchema

  model :user

  #=== FIELDS ===#

  field :username, :string,
    description: 'The url-safe string used to represent this user in urls and other external-facing contexts. Case insensitive.',
    max_from: :username,
    example: 'NielArmstrong69'

  field :is_private, :boolean,
    description: 'True if this user is part of a private email domain. Private email domains restrict the visibility of users ' \
      'with certain email addresses to only other users on their email domain. If this is a private user account, then only the id, ' \
      'username, email hash and image will be visible to users without access to see the domain.',
    example: false

  field :email_verification_needed, :boolean,
    description: "True if the user's email address needs to be confirmed.",
    example: false

  field :email_inactive, :boolean,
    description: "True if the user's email address has been blocked.",
    example: false

  field :email_hash, :string,
    description: "A hashed version of the user's email address",
    example: 'sha256$5c30dbe2195a1a8aa6e2575e8bf33f5a1860370df5b7f07096baffbe26f21e29'

  field :email_salt, :string,
    description: "The salt which is appended to the user's email address before hashing.",
    example: '53304184752c3625a7ce92a2e5de7653'

  field :proxy_group_id, [:string, :id],
    description: 'If type is `group` this indicates the group for which this user is a proxy.'

  field :proxy_app_id, [:string, :id],
    description: 'If type is `app` this indicates the app for which this user is a proxy.'

  field :image_url, [:string, :url],
    description: "URL of this user's full-sized avatar image, 500 pixels by 500 pixels",
    example: 'https://badgelist.s3.amazonaws.com/u/user/52e20f4c00485d4de3000001/f264877aeb8f8d9afebba9958fe260b7.jpeg'

  field :image_medium_url, [:string, :url],
    description: "URL of this user's medium-sized avatar image, 200 pixels by 200 pixels",
    example: 'https://badgelist.s3.amazonaws.com/u/user/52e20f4c00485d4de3000001/medium_f264877aeb8f8d9afebba9958fe260b7.jpeg'

  field :image_small_url, [:string, :url],
    description: "URL of this user's small-sized avatar image, 50 pixels by 50 pixels",
    example: 'https://badgelist.s3.amazonaws.com/u/user/52e20f4c00485d4de3000001/small_f264877aeb8f8d9afebba9958fe260b7.jpeg'

  field :type, :string,
    description: 'Indicates whether this is an individual user or a group user. Individual users are user accounts which were ' \
      'created using the normal registration process and represent individuals. Group users are proxy users created automatically by ' \
      'the system which represent groups and are used to interact with the API.',
    enum_from: :type

  field :name, :string,
    description: 'The full name of this user',
    max_from: :name,
    example: 'Niel Armstrong'

  field :job_title, :string,
    description: "Optional profile field indicating the user's job title",
    max_from: :job_title,
    example: 'Retired Astronaut'

  field :organization_name, :string,
    description: "Optional profile field indicating the user's organizational affiliation",
    max_from: :organization_name,
    example: 'NASA'

  field :website, :string,
    description: "Optional profile field indicating the website of the user or the user's organization",
    max_from: :website,
    example: 'https://www.nasa.gov'

  field :bio, :string,
    description: 'Optional profile field indicating biographic details about the user',
    max_from: :website,
    example: 'An American astronaut and aeronautical engineer. First person to walk on the Moon.'

  field :badge_count, :integer,
    description: 'The total number of badges awarded to this user',
    example: 235

  field :last_active, [:string, :date],
    description: 'The date on which this user was last active'

  field :async_poller_id, [:string, :id],
    description: 'When async updates are pending this contains the id of the poller record which can be used to track the ' \
      'background process'

  #=== SCHEMAS ===#

  attributes_schema :output

  meta_schema :self

  relationship_schemas \
    proxy_group: 'If type is `group` this indicates the group for which this user is a proxy.',
    proxy_app: 'If type is `app` this indicates the app for which this user is a proxy.',
    groups: 'The groups to which this user belongs, either as a member or as an admin',
    portfolios: 'The badge portfolios which this user has created',
    app_user_memberships: 'All app memberships for this user, including inactive ones'
    # authentication_tokens: '' #==> Not including this for now

end