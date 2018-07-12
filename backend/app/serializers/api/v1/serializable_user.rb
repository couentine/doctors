class Api::V1::SerializableUser < Api::V1::SerializableDocument
  type :user

  #=== FIELDS ===#

  field :username,                      from: :username_with_caps
  field :is_private
  field :email_verification_needed
  field :email_inactive
  field :email_hash,                    from: :identity_hash
  field :email_salt,                    from: :identity_salt

  field :image_url,                     from: :avatar_image_url
  field :image_medium_url,              from: :avatar_image_medium_url
  field :image_small_url,               from: :avatar_image_small_url

  field :type
  field :name
  
  field :job_title
  field :organization_name
  field :website
  field :bio
  field :badge_count,                   from: :expert_badge_count
  field :last_active,                   convert: :iso8601

  field :proxy_app_id
  field :proxy_group_id
  field :async_poller_id,               from: :async_callback_poller_id

  #=== LINKS ===#
  
  self_links
  
  #=== RELATIONSHIPS ===#
  
  relationships \
    :proxy_group,
    :proxy_app,
    :groups,
    :portfolios,
    :app_user_memberships,
    :authentication_tokens
end