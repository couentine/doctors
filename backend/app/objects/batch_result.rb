# This class is used to store the result items of batch processes.
# It mostly exists in order to provide a clean abstraction for serialization.

class BatchResult

  attr_accessor :index, :type, :success, :error_message, :id

  def initialize(index: nil, type: nil, success: nil, error_message: nil, id: nil)
    @index = index
    @type = type
    @success = success
    @error_message = error_message
    @id = id
  end

  def to_h
    {
      index: @index,
      type: @type,
      success: @success,
      error_message: @error_message,
      id: @id,
    }
  end
  
  def to_s
    to_h.to_s
  end

end