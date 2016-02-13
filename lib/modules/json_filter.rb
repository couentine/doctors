module JSONFilter
  
  # === CONSTANTS === #
  DEFAULT_JSON_FIELDS = [:_id] # Fields to always include
  
  # Filters the json properties based on what the filter_user can see
  # Looks for the following constants in the model (self.class::CONSTANT)
  #   JSON_FIELDS => List of fields to return for non-admins (passed as :only)
  #   JSON_MOCK_FIELDS => Hash of fields to include under a different name 
  #     (key = string of key in json output, value = symbol of model field or method to return)
  #   JSON_METHODS => List of class methods to include in return (passed as :methods)
  # Looks for the following keys in option hash: 
  #   :use_default_method => if true this will skip all the custom logic and return super method
  #   :filter_user => specify the user to filter the fields by
  #   :only => Manually specify fields to include (overrides model constant)
  #   :methods => Manually specify methods to include (overrides model constant)
  def as_json(options={})
    if options[:use_default_method]
      # Skip this method altogether and pass options to super (without the use_default_method key)
      options.delete :use_default_method
      return_value = super(options)
    else
      # First grab the JSON_METHODS
      if options.has_key? :methods
        methods = options[:methods]
      else
        methods = (defined? self.class::JSON_METHODS) ? self.class::JSON_METHODS : []
      end

      if options[:filter_user] && options[:filter_user].admin?
        # Return all fields
        return_value = super(methods: methods)
      else
        if options.has_key? :only
          only = options[:only]
        else
          only = [DEFAULT_JSON_FIELDS]
          only << self.class::JSON_FIELDS if defined? self.class::JSON_FIELDS
          only.flatten!.uniq!
        end

        return_value = super(only: only, methods: methods)
      end

      # Now add the mock fields if present
      self.class::JSON_MOCK_FIELDS.each do |key, value|
        return_value[key] = eval("self.#{value}")
      end if defined? self.class::JSON_MOCK_FIELDS
    end

    return_value
  end

end