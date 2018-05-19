class Api::V1::DeserializableEndorsement < Api::V1::DeserializableHash

  attr_reader :endorsement, :endorsements
  
  TYPE = :endorsement
  ATTRIBUTES = [:email, :summary, :body]

  def initialize(params)
    @endorsement = nil
    @endorsements = nil

    super(params)

    @endorsement = @hash
    @endorsements = @hashes
  end

end