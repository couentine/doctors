class Api::V1::Schemas::PortfolioSchemas < Api::V1::Schemas::ApiSchema

  model :portfolio, model_class: Log

  #=== FIELDS ===#

  field :status, :string,
    enum_from: :status,
    description: "The status indicates where the portfolio is in the feedback process:\n" \
      "- **draft**: The portfolio is in a working state, the badge is unissued\n" \
      "- **requested**: Feedback has been requested but not yet provided\n" \
      "- **endorsed**: Portfolio has been endorsed, badge is issued, user is a badge holder"

  field :retracted, :boolean,
    description: 'When set to true by a group admin, the badge is retracted',
    example: false

  field :badge_id, [:string, :id],
    description: 'The id of the parent badge',
    example: '591b91ac95421f51f294b389'

  field :user_id, [:string, :id],
    description: 'The id of the parent user',
    example: '591b8c2295421f5205bf709e'

  field :user_name, :string,
    description: 'The name of this user',
    example: 'Niel Armstrong'

  field :user_username, :string,
    description: 'The url-safe string used to represent this user in urls and other external-facing contexts. Case insensitive.',
    example: 'NielArmstrong69'

  field :show_on_badge, :boolean,
    description: 'User visibility control specifying whether this user shows up in the lists of badge seekers / holders',
    example: true

  field :show_on_profile, :boolean,
    description: 'User visibility control specifying whether this badge shows up on the user\'s badge profile',
    example: true

  field :receive_feedback_request_emails, :boolean,
    description: 'User control specifying whether to receive feedback requests for this badge',
    example: true

  field :started_at, [:string, :date],
    description: 'The date which the portfolio was created'

  field :requested_at, [:string, :date],
    description: 'The date which feedback was most recently requested'

  field :withdrawn_at, [:string, :date],
    description: 'The date which feedback was most recently withdrawn'

  field :issued_at, [:string, :date],
    description: 'The date which the badge was awarded'

  field :retracted_at, [:string, :date],
    description: 'The date which the badge was retracted'

  field :originally_issued_at, [:string, :date],
    description: 'If a badge is retracted, the original issue date is preserved here'

  #=== SCHEMAS ===#

  attributes_schema :output

  meta_schema :user

  relationship_schemas \
    badge: 'The badge to which this portfolio belongs',
    user: 'The user to which this portfolio belongs'

end