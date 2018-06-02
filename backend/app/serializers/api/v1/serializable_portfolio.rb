class Api::V1::SerializablePortfolio < Api::V1::SerializableDocument
  type :portfolio

  #=== FIELDS ===#

  field :status
  
  field :badge_id
  field :user_id
  field :user_name
  field :user_username,                 from: :user_username_with_caps 

  field :show_on_badge
  field :show_on_profile
  field :receive_feedback_request_emails, 
    from: :receive_validation_request_emails

  field :retracted

  field :started_at,                    from: :date_started,          convert: :iso8601
  field :requested_at,                  from: :date_requested,        convert: :iso8601
  field :withdrawn_at,                  from: :date_withdrawn,        convert: :iso8601
  field :issued_at,                     from: :date_issued,           convert: :iso8601
  field :retracted_at,                  from: :date_retracted,        convert: :iso8601
  field :originally_issued_at,          from: :date_originally_issued,convert: :iso8601

  #=== LINKS ===#
  
  link :self do 
    "/api/v1/portfolios/#{@object.id.to_s}" 
  end
  link :self_web do 
    @object.full_url(@group || @object.badge.group, @badge || @object.badge, @user || @object.user)
  end

  #=== RELATIONSHIPS ===#

  relationships \
    :user,
    :badge
end