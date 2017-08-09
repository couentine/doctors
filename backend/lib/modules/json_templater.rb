module JSONTemplater
  
  # Include this module in an active model in order to provide multiple templates of JSON-ified
  # field collections. To use you should add a JSON_TEMPLATES hash constant where the keys are
  # are the templates and the values are lists of symbols representing either fields or instance
  # methods one the model.

  # OPTIONS (with default value):
  # - stringify_ids (true): Turns instances of BSON::ObjectId into strings.
  # - unixify_times (true): Turns instances of ActiveSupport::TimeWithZone into unix timestamps.
  # - current_user (nil): Sets the current_user attribute then restores original value afterward
  
  def json_from_template(key, options = { stringify_ids: true, unixify_times: true })
    if self.class::JSON_TEMPLATES[key].blank?
      throw "The '#{key}' key in  #{self.class}::JSON_TEMPLATES is blank."
    else
      return_hash = {}
      current_value = nil

      # Set the current user if needed, but first store the previous value so we can restore it
      if options[:current_user]
        previous_current_user_value = self.current_user
        self.current_user = options[:current_user]
      end

      self.class::JSON_TEMPLATES[key].each do |field_or_method|
        current_value = self.send(field_or_method)
        if options[:stringify_ids] && (current_value.class == BSON::ObjectId)
          current_value = current_value.to_s
        elsif options[:unixify_times] && (current_value.class == ActiveSupport::TimeWithZone)
          current_value = current_value.to_i
        end

        return_hash[field_or_method] = current_value
      end

      # Restore the previous current user value, just in case it was something important
      if options[:current_user]
        self.current_user = previous_current_user_value
      end

      return_hash
    end
  end

  # This is a shortcut method for brevity when desired
  def json(key, options = { stringify_ids: true })
    return json_from_template(key, options)
  end

  # Extend the attached class with a class level method
  
  extend ActiveSupport::Concern
  
  included do
    # This converts an array of items (with JSONTemplater setup on their classes) into json
    def self.array_json(array_of_templated_items, key, options = { stringify_ids: true })
      return_list = []

      array_of_templated_items.each do |item|
        return_list << item.json_from_template(key, options)
      end

      return_list
    end
  end

end