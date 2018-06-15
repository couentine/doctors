class Api::V1::Schemas::AppSchemas < Api::V1::Schemas::ApiSchema
  
  model :app
  
  #=== FIELDS ===#

  field :name, :string,
    description: 'Display name of the app',
    max_from: :name,
    example: 'Acme LMS'

  field :slug, [:string, :slug],
    description: "The 'dash-case' string used to represent this app in urls and other external-facing contexts. " \
      "Must be all lower case and contain only letters, numbers and dashes.\n" \
      "\n" \
      "Note: The slug is also used as the programmatic identifier of this app when tracking activities throughout the API. " \
      "It is best to choose a slug and then not change it once your app is being used by groups and referenced by other developers.",
    max_from: :slug,
    example: 'acme-lms'

  field :summary, :string,
    description: 'Short summary of the app and which sorts of groups and users are able to join it',
    max_from: :summary,
    example: "Acme's LMS is a custom-built application used by Acme employees and customers."

  field :user_joinability, :string,
    description: "Controls whether users are able to create memberships:\n" \
      "- `open` lets users create memberships which are automatically approved\n" \
      "- `by_request` lets users create memberships which need to be approved by app admins\n" \
      "- `closed` does not let users create memberships",
    enum_from: :joinability,
    example: :active

  field :group_joinability, :string,
    description: "Controls whether groups are able to create memberships:\n" \
      "- `open` lets groups create memberships which are automatically approved\n" \
      "- `by_request` lets groups create memberships which need to be approved by app admins\n" \
      "- `closed` does not let groups create memberships",
    enum_from: :joinability,
    example: :active

  field :status, :string,
    description: 'The current status of the app',
    enum_from: :status,
    example: :active

  field :review_status, :string,
    description: 'The status of the app in the Badge List review process',
    enum_from: :review_status,
    example: :approved

  field :required, :boolean,
    description: 'Indicates whether this app is a required part of the core Badge List platform. Required apps are built into the ' \
      'platform and cannot be unjoined without deleting your user account.',
    example: false

  field :description, [:string, :html],
    description: 'Longer HTML-formatted free text description of the app',
    max_from: :description,
    example: '<p>In order to access the LMS <a href="...">go here</a>.</p><p>For more details...</p>'

  field :organization, :string,
    description: 'The name of the organization which owns or manages the app',
    max_from: :organization,
    example: 'Acme Inc'

  field :website, [:string, :url],
    description: 'An optional link to the app website or any other relevant page',
    max_from: :website,
    example: 'https://www.acme.com'

  field :email, [:string, :email],
    description: 'The primary contact email which users can use to receive support or ask questions about the app',
    max_from: :email,
    example: 'support@acme.com'

  field :image_url, [:string, :url],
    description: 'URL of the full-sized app image, 500 x 500',
    example: 'https://badgelist.s3.amazonaws.com/u/app/52f41faac56ca3af4a000008/app.png'

  field :image_medium_url, [:string, :url],
    description: 'URL of the resized app image, 200 x 200',
    example: 'https://badgelist.s3.amazonaws.com/u/app/52f41faac56ca3af4a000008/medium_app.png'

  field :image_small_url, [:string, :url],
    description: 'URL of the resized app image, 50 x 50',
    example: 'https://badgelist.s3.amazonaws.com/u/app/52f41faac56ca3af4a000008/small_app.png'

  field :processing_image, :boolean,
    description: 'When the image is changed, this boolean indicates that the new image is still being processed in the background',
    example: false

  field :user_count, :integer,
    description: 'The number of active user members',
    example: 230

  field :group_count, :integer,
    description: 'The number of active group members',
    example: 55

  field :owner_id, [:string, :id],
    description: "The user id of the app's owner"
  
  field :creator_id, [:string, :id],
    description: "The user id of the app's creator"

  #=== SCHEMAS ===#

  attributes_schema :output

  attributes_schema :input
  
  meta_schema :creator

  relationship_schemas \
    owner: 'The user who owns the app',
    creator: 'The original creator of the app',
    app_user_memberships: 'All user memberships for this app, including inactive ones',
    app_group_memberships: 'All group memberships for this app, including inactive ones'

end