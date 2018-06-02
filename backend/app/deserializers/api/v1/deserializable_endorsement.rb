class Api::V1::DeserializableEndorsement < Api::V1::DeserializableHash

  type :endorsement
  
  field :email
  field :summary
  field :body

end