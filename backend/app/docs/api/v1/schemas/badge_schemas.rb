class Api::V1::Schemas::BadgeSchemas < Api::V1::Schemas::ApiSchema
  
  model :badge
  
  #=== FIELDS ===#

  field :creator_id, [:string, :id],
    description: "The user id of the group's creator"
    
  field :slug, [:string, :slug],
    description: 'The url-safe string used to represent this badge in urls and other external-facing contexts. Case insensitive.',
    max_from: :url,
    example: 'Orbital-Mechanics'

  field :name, :string,
    description: 'Display name of the badge',
    max_from: :name,
    example: 'Orbital Mechanics'

  field :summary, :string,
    description: 'Short summary of the badge and what badge holders have done to earn the badge',
    max_from: :summary,
    example: 'Demonstrated understanding of orbital and launch mechanics. Acceleration, braking, orbital velocity calculations.'

  field :visibility, :string,
    description: 'Specifies who can see this badge: Everyone on the public internet (`public`), only group members (`private`) or ' \
      'only badge members (`hidden`)',
    enum_from: :visibility


  field :feedback_request_count, [:integer, :int64],
    description: 'The number of badge portfolios currently requesting feedback',
    example: 3

  field :seeker_count, [:integer, :int64],
    description: 'The number of badge portfolios which have not yet been endorsed, also referred to as learner count',
    example: 12

  field :holder_count, [:integer, :int64],
    description: 'The number of badge portfolios which have been endorsed, also referred to as expert count',
    example: 80

  field :image_url, [:string, :url],
    description: 'URL of the full-sized badge image PNG, 500 pixels by 500 pixels',
    example: 'https://badgelist.s3.amazonaws.com/u/badge/52f434f0ef83df7c9200000f/designed_image/badge.png'

  field :image_medium_url, [:string, :url],
    description: 'URL of the resized badge image PNG, 200 pixels by 200 pixels',
    example: 'https://badgelist.s3.amazonaws.com/u/badge/52f434f0ef83df7c9200000f/designed_image/medium_badge.png'

  field :image_small_url, [:string, :url],
    description: 'URL of the resized badge image PNG, 50 pixels by 50 pixels',
    example: 'https://badgelist.s3.amazonaws.com/u/badge/52f434f0ef83df7c9200000f/designed_image/small_badge.png'

  field :group_id, [:string, :id],
    description: "The id of the group record"

  field :creator_id, [:string, :id],
    description: "The user id of the badge's creator"
  
  #=== SCHEMAS ===#

  attributes_schema :output
  
  meta_schema :creator

  relationship_schemas \
    group: 'The parent group to which the badge belongs',
    portfolios: 'The list of portfolios for this badge',
    creator: 'The original creator user of the badge'

end