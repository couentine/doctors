class Api::V1::DeserializableEndorsement < Api::V1::DeserializableHash

  type :endorsement
  
  field :email
  field :name
  field :summary
  field :body
  field :requirement
  field :format

end