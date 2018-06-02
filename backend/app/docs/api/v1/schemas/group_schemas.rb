class Api::V1::Schemas::GroupSchemas < Api::V1::Schemas::ApiSchema
  
  model :group
  
  #=== FIELDS ===#

  field :slug, [:string, :slug],
    description: 'The url-safe string used to represent this group in urls and other external-facing contexts. Case insensitive.',
    max_from: :url,
    example: 'NASA-Training'

  field :name, :string,
    description: 'Display name of the group',
    max_from: :name,
    example: 'NASA Astronaut Corps'

  field :summary, :string,
    description: 'Short summary text describing the group and its purpose',
    max_from: :description,
    example: 'The Astronaut Corps is dedicated selecting the best and brightest, then training them as crew members for US and ' \
      'international space missions.'
  
  field :location, :string,
    description: 'Free text field which is intended to describe the location of the group',
    max_from: :location,
    example: 'Lyndon B. Johnson Space Center, Houston, Texas'

  field :type, :string,
    description: 'Indicates whether or not this is a paid group',
    enum_from: :type,
    example: 'paid'

  field :color, :string,
    description: 'The primary color used for the visual styling of the group. The actual colors used come from the ' \
      'Google Material Design Color Palette.',
    enum_from: :color,
    example: 'indigo'
  
  field :member_count, :integer,
    description: 'The number of group members',
    example: 2187

  field :admin_count, :integer,
    description: 'The number of group admins',
    example: 7

  field :total_user_count, :integer,
    description: 'The number of total users in the group (including both members and admins)',
    example: 2194

  field :badge_count, :integer,
    description: 'The number of badges in the group',
    example: 102

  field :image_url, [:string, :url],
    description: 'URL of the full-sized group image, 500 pixels wide and/or long',
    example: 'https://badgelist.s3.amazonaws.com/u/group/52f41faac56ca3af4a000008/NASA_Logo.png'

  field :image_medium_url, [:string, :url],
    description: 'URL of the resized group image, 200 pixels wide and/or long',
    example: 'https://badgelist.s3.amazonaws.com/u/group/52f41faac56ca3af4a000008/medium_NASA_Logo.png'

  field :image_small_url, [:string, :url],
    description: 'URL of the resized group image, 50 pixels wide and/or long',
    example: 'https://badgelist.s3.amazonaws.com/u/group/52f41faac56ca3af4a000008/small_NASA_Logo.png'

  field :member_visibility, :string,
    description: 'Controls the visibility of the list of members',
    enum_from: :visibility

  field :admin_visibility, :string,
    description: 'Controls the visibility of the list of admins',
    enum_from: :visibility

  field :badge_copyability, :string,
    description: 'Controls the who can copy badges from the group',
    enum_from: :copyability

  field :owner_id, [:string, :id],
    description: "The user id of the group's owner"
  
  field :creator_id, [:string, :id],
    description: "The user id of the group's creator"

  #=== SCHEMAS ===#

  attributes_schema :output

  meta_schema :creator

  relationship_schemas \
    badges: 'The badges contained in this group',
    users: 'The members and admins of this group',
    apps: 'All apps for which this group is currently an active member',
    app_group_memberships: 'All app memberships for this group, including inactive ones',
    owner: 'The current user owner of the group',
    creator: 'The original creator user of the group'

end