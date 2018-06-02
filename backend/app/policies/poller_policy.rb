class PollerPolicy < ApplicationPolicy

  #=== ACTION POLICIES ===#

  standard_actions :app,
    show_roles: :everyone,
    update_roles: [:bl_admin],
    destroy_roles: [:bl_admin]

  #=== FIELD POLICIES ===#

  READONLY_FIELD = { visible_to: :everyone, editable_by: :nobody }

  field :status,              READONLY_FIELD
  field :progress,            READONLY_FIELD
  field :completed,           READONLY_FIELD
  field :waiting_message,     READONLY_FIELD
  field :message,             READONLY_FIELD
  field :results,             READONLY_FIELD

end