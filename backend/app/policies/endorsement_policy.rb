class EndorsementPolicy < ApplicationPolicy

  #=== ACTION POLICIES ===#

  action :create,
    roles: :everyone,
    permissions: ['portfolios:review']

  #=== FIELD POLICIES ===#

  CREATOR_FIELD = { visible_to: :all_roles, editable_by: :all_roles }

  field :email,               CREATOR_FIELD
  field :summary,             CREATOR_FIELD
  field :body,                CREATOR_FIELD
  field :requirement,         CREATOR_FIELD
  field :format,              CREATOR_FIELD

end