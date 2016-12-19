module AuditHistory
  # Add this to a model to keep a field audit history in a standardized format.
  
  # Adds two methods:
  # - Object.new_with_audit(object_params, current_user_id)
  # - object.update_attributes_with_audit(object_params, current_user_id) 

  # REQUIRES a AUDIT_HISTORY_FIELDS hash constant in model definition.
  # There should be a key for each field which needs to be tracked. Two defition formats:
  # - SIMPLE >> Use the simple format to leave 'include_values' feature disabled
  #          >> field_name: 'Display Name'
  # - ADVANCED >> Use advanced format to enable the 'include values' feature for this field
  #            >> field_name: { display_name: 'Display Name', include_values: true }

  # Injects the following three fields
  # - created_by >> BSON::ObjectId of user who created this record
  # - updated_by >> BSON::ObjectId of user who updated this record
  # - audit_history >> Sequantial list of changes to AUDIT_HISTORY_FIELDS, each is hash w/ keys:
  #   - updated_at: Time
  #   - updated_by: Stringified version of user id
  #   - display_name: String of the specified user-friendly field name
  #   - field_name: Stringified version of the actual field name
  #   - old_value: Only set if 'include values' feature is enabled for field
  #   - new_value: Only set if 'include values' feature is enabled for field

  # === INJECTED FIELD DEFINITIONS === #

  extend ActiveSupport::Concern
  
  included do
   field :created_by,       type: BSON::ObjectId # Audit field, not a relationship
   field :updated_by,       type: BSON::ObjectId # Audit field, not a relationship
   field :audit_history,    type: Array, default: [] # Sequential list of changes
  end
  
  # === CORE METHODS === #

  def self.new_with_audit(object_params, current_user_id)
    # First we call the standard Object.new method
    return_object = self.class.new(object_params)

    # Then we add our audit values
    return_object.created_by = current_user_id
    return_object.audit_history = return_object.build_audit_rows(current_user_id)

    # Then we return the object
    return_object
  end

  def update_attributes_with_audit(object_params, current_user_id)
    # First we call the standard assign attributes method
    self.set_attributes(object_params)

    # Then we add our audit values
    self.updated_by = current_user_id
    self.audit_history += self.build_audit_rows(current_user_id)

    # Then we save (thus returning true or false just like the standard update_attributes)
    self.save
  end
  
  # === UTILITY METHOD === #

  # This checkes the standard Dirty methods to see what has changed on self, 
  # then builds the audit rows with the provided current_user_id
  # NOTE: If no audited fields have changed then it will return an empty array
  def build_audit_rows(current_user_id)
    return_list = []
    user_id_string = current_user_id.to_s # stringify if needed
    audit_time = Time.now # We want to use the same timestamp for the entire set of rows

    field_name, display_name, include_values, audit_row = nil, nil, false, {}
    AUDIT_HISTORY_FIELDS.each do |field_symbol, settings|
      field_name = field_symbol.to_s
      display_name = (settings.class == Hash) ? settings[:display_name] : settings
      include_values = (settings.class == Hash) && (settings[:include_values] == true)
      
      if self.changed.include?(field_name)  
        audit_row = { updated_at: audit_time, updated_by: user_id_string, field_name: field_name,
         display_name: display_name }

        if include_values
          audit_row[:old_value] = self[field_name + '_was']
          audit_row[:new_value] = self[field_name]
        end

        return_list << audit_row
      end
    end

    return_value
  end

end