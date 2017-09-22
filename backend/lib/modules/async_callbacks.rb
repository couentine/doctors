module AsyncCallbacks
  # Add this to a model to add asynchronous callbacks which fire after save.
  #
  # Adds three fields to the mode:
  # - async_callback_poller_id: Set to the id of a poller if there are callbacks running. Cleared when they are complete.
  # - async_callback_errors: A list of error message encountered during the last callback execution (equal to empty array if none).
  # - async_callback_status: A string used internally to manage the callback execution process. Do not modify this directly.
  #
  # HOW TO ADD AN ASYNC CALLBACK:
  #
  # 1. Add an ASYNC_CALLBACKS constant in the model (just after the normal callbacks) that looks like this:
  #
  #    ASYNC_CALLBACKS = [:do_something_when_condition]
  #
  # 2. Then create a question mark method meant to be called after_save (insert and update). It returns true if the callback should run 
  #    and false if the callback should not run.
  #
  #    def do_something_when_condition?
  #      # Remember that this will run after insert AND update so you need to explicitly check for the appropriate state
  #      new_record? && some_field_changed? && (some_field == 'some value')
  #    end
  #
  # 3. Then create an exlamation point method which will be called from an asynchronous thread if the condition is met.
  #    Keep in mind that there may be many different async callbacks being run on the record during the same asynchronous transaction.
  #    The record will automatically be saved when all of the relevant callbacks have run, so you don't need to ecplicitly save, but you 
  #    can if needed.
  #
  #    def do_something_when_condition!
  #      # Do processor / query intensive stuff here
  #      self.field = 'complete!'
  #    end
  #

  # === INJECTED FIELD DEFINITIONS === #

  extend ActiveSupport::Concern
  
  included do
    field :async_callback_poller_id,    type: BSON::ObjectId
    field :async_callback_status,       type: String # Process Flow: nil > pending > executing > nil
    field :async_callback_errors,       type: Array, default: []
  
    # === REGISTER CALLBACK CHECKERS === #

    before_save :create_async_poller
    after_save :queue_async_callbacks

    # === THE CALLBACK EXECUTOR === #

    # Called automatically, do not invoke directly.
    def self.execute_async_callbacks(record_id, callbacks_to_execute)
      record = self.find(record_id)

      if (record.async_callback_status == 'pending')
        poller = Poller.find(record.async_callback_poller_id) rescue nil

        record.async_callback_status = 'executing'
        record.save

        callbacks_to_execute.each do |callback_name|
          begin
            record.send(callback_name.to_s + '!')
          rescue Exception => e
            record.async_callback_errors << e.to_s
          end
        end

        record.async_callback_status = nil
        record.async_callback_poller_id = nil
        record.save
        
        if poller
          poller.status = 'successful'
          poller.save
        end
      end
    end

  end

  # Returns an array of strings of the callback names with true return values for their question mark methods.
  def async_callbacks_to_execute
    if defined?(self.class::ASYNC_CALLBACKS)
      self.class::ASYNC_CALLBACKS.select do |callback_name_symbol|
        self.send(callback_name_symbol.to_s + '?')
      end
    else
      []
    end
  end

  def create_async_poller
    if async_callback_status.blank? && async_callbacks_to_execute.present?
      poller = Poller.new
      poller.data = {
        record_id: id.to_s,
        poller_type: 'async_callback_poller',
        async_model: self.class.name,
        callbacks_to_execute: async_callbacks_to_execute
      }
      poller.save

      self.async_callback_poller_id = poller.id
      self.async_callback_errors = []
      self.async_callback_status = 'pending'
    end
  end

  def queue_async_callbacks
    if async_callback_status_changed? && (async_callback_status == 'pending')
      callbacks_to_execute = async_callbacks_to_execute

      if callbacks_to_execute.present?
        self.class.delay(queue: 'high', retry: false).execute_async_callbacks(id.to_s, callbacks_to_execute)
      end
    end
  end

end