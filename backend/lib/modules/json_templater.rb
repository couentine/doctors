module JSONTemplater
  
  # Include this module in an active model in order to provide multiple templates of JSON-ified field collections. To use you should add a 
  # JSON_TEMPLATES hash constant where the keys are are the templates and the values are lists of symbols representing either fields or 
  # instance methods on the model class. To use a different name, include a hash with one key (the field or instance method) 
  # and one value (a symbol or string which should be used as the key in the json output).
  #
  # You can specify user-permission-based visibility within a particular template by including another level of keys underneath the main
  # template key. The `:everyone` key is used regardless of user permissions. The remaining keys should exactly match one of the symbols
  # returned by a `current_user_permissions` method on the model instance. They will be included if the corresponding key returns `true`.
  #
  # In the examples, api_v1 is an example of a template which looks the same regardless of user. api_v2 is an example of a 
  # user-permission-based implementation. To use api_v2 you would need to specify the `current_user` option when calling JSONTemplater.
  #
  #===[ EXAMPLE ]===#
  #
  # JSON_TEMPLATES = {
  #   api_v1: [:id, :name, :url, { :url_with_caps => :slug }, :another_field]
  #   api_v2: {
  #     everyone: [:id, :name, :url, { :url_with_caps => :slug }, :another_field],
  #     can_see_badges: [:badge_urls, { :badge_ids_as_strings => :badge_ids }]
  #   } # ==> depends on current_user_permissions method which returns hash with `:can_see_badges` boolean key
  # } 
  #
  #==[ OPTIONS (with default value) ]===#
  #
  # - stringify_ids (true): Turns instances of BSON::ObjectId into strings.
  # - unixify_times (true): Turns instances of ActiveSupport::TimeWithZone into unix timestamps.
  # - current_user (nil): Sets the current_user attribute then restores original value afterward
  
  def json_from_template(key, options = {})
    return_hash = {}
    current_value_symbol = nil
    current_label = nil
    current_value = nil
    stringify_ids = options[:stringify_ids].nil? || (options[:stringify_ids] == true)
    unixify_times = options[:unixify_times].nil? || (options[:unixify_times] == true)

    throw "The '#{key}' key in  #{self.class}::JSON_TEMPLATES is blank." if self.class::JSON_TEMPLATES[key].blank?

    # Set the current user if needed, but first store the previous value so we can restore it
    if options[:current_user]
      if self.respond_to? :current_user_accessor
        # For badges there is already a current_user FIELD so we have another name for the accessor
        previous_current_user_value = self.current_user_accessor
        self.current_user_accessor = options[:current_user]
      else
        # Assume that if there's no current_user_accessor that we're supposed to use current_user
        previous_current_user_value = self.current_user
        self.current_user = options[:current_user]
      end
    end

    # We want to convert any non-user-permission based templates into user-permission-based templates
    if self.class::JSON_TEMPLATES[key].class == Hash
      templates_by_permission = self.class::JSON_TEMPLATES[key]
      current_user_permissions = self.current_user_permissions
    elsif self.class::JSON_TEMPLATES[key].class == Array
      templates_by_permission = { everyone: self.class::JSON_TEMPLATES[key] }
      current_user_permissions = nil
    else
      throw "Invalid JSON_TEMPLATES structure for key '#{key}'."
    end

    templates_by_permission.each do |permission_set, template_items|
      if (permission_set == :everyone) || (current_user_permissions[permission_set] == true)
        templates_by_permission[permission_set].each do |template_item|
          if template_item.class == Hash
            current_value_symbol = template_item.keys.first
            current_label = template_item.values.first
          else
            current_value_symbol = template_item
            current_label = template_item
          end
          
          current_value = self.send(current_value_symbol)
          if stringify_ids && (current_value.class == BSON::ObjectId)
            current_value = current_value.to_s
          elsif stringify_ids && (current_value.class == Array) && !current_value.empty? \
              && (current_value.first.class == BSON::ObjectId)
            current_value = current_value.map do |item|
              (item.class == BSON::ObjectId) ? item.to_s : item
            end
          elsif unixify_times && (current_value.class == ActiveSupport::TimeWithZone)
            current_value = current_value.to_i
          end

          return_hash[current_label] = current_value
        end
      end
    end

    # Restore the previous current user value, just in case it was something important
    if options[:current_user]
      self.current_user = previous_current_user_value
    end

    return_hash
  end

  # This is a shortcut method for brevity when desired
  def json(key, options = {})
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