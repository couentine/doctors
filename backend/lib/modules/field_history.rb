#==========================================================================================================================================#
# 
# FIELD HISTORY MODULE
# --------------------
# 
# NOTE: This module superscedes `audit_history.rb` as of May 2018.
# Add this to a model to keep a field history as embedded instances of `FieldHistoryItem` records.
# 
# ## How to Add Field History to a Model Class ##
# 
# 1. Add `include FieldHistory` to the top of the class.
# 2. Add a metadata hash to the fields you want to track. It should contain a `:history_of` key equal to either `:values` or `:times`.
#   NOTE: For now it seems best to only track the history of editable fields (not calculated fields which are set by callbacks or other
#   automated processes). Otherwise it becomes more difficult to "restore" a previous revision.
#   ```
#   field :name,          type: String,               metadata: { history_of: :values }   # tracks update time, old value and new value
#   field :fancy_pants,   type: SuperComplexObject,   metadata: { history_of: :times }    # tracks only the upate time
#   ```
# 3. You're done!
#   - WARNING: A before_save callback is added in order to generate field_history_items every time the record is saved. 
#     It will throw an error if you try and create or save a record without setting `field_history_user`.
#     Going forward you will have to set the `field_history_user` accessor on each model item every single time you save it!
#   - You can also use the `model_instance.save_as(current_user)` method to set the field history user in a single command.
#   - You can also use the `model_instance.save_without_history` method to skip the field history altogether.
#     WARNING: Be careful about saving without history. As long as you're not changing tracked fields you're fine, but if you change 
#     tracked fields then you will end up ruining the audit history in a way that is confusing and impossible to programmatically resolve.
#     If you need to change watched fields in a rake task or something, it's best to use an actual user and track the history. You can use 
#     `ENV['bl_admin_account_email']` to get the email address of the standard admin account which is ok to use for this sort of thing.
#   - A `field_history_revision` field is added to the model to track the current revision number.
#   - An embedded `field_history_items` relation is added to the model to store the items
# 
#==========================================================================================================================================#
module FieldHistory

  extend ActiveSupport::Concern
  
  included do
    
    # This is required every single time you save a field-history-enabled model item.
    # It sets the user on the created field history items.
    attr_accessor :field_history_user

    # Set this to true to suppress the field history for one save.
    # You can also use the `save_without_history` method.
    attr_accessor :skip_field_history

    # This is used internally, do not modify it directly
    attr_accessor :field_history_is_running

    
    # === RELATIONS === #
    
    # Use this to access the field history items on the parent model. 
    # It's ok to manually change / reset this if needed.
    embeds_many :field_history_items,       as: :field_history_list
    
    # === FIELDS === #

    # This is incremented with each batch of changes and serves to group field history items into revision batches.
    # It's ok to manually change / reset this field if needed (perhaps as part of a larger versioning system).
    field :field_history_revision,          type: Integer, default: 1
    
    # === CALLBACKS === #
    
    before_save :increment_field_history_revision
    after_save :build_field_history_items

  end

  # === PUBLIC INSTANCE METHODS === #

  def save_as(current_user)
    self.field_history_user = current_user
    self.save
  end
  
  def save_as!(current_user)
    self.field_history_user = current_user
    self.save!
  end

  def destroy_as(current_user)
    self.field_history_user = current_user
    self.destroy
  end
  
  def destroy_as!(current_user)
    self.field_history_user = current_user
    self.destroy!
  end

  def save_without_history
    self.skip_field_history = true
    return_value = self.save
    self.skip_field_history = nil

    return return_value
  end

  # === PROTECTED METHODS === #

  protected
    
  # This checkes the standard rails field dirty methods to see what has changed on self, then if so it increments the 
  # field_history_revision so that an additional save is not required to commit it to the db.
  # Raises an ArgumentError if the `field_history_user` accessor is unset (unless skip_field_history is set).
  def increment_field_history_revision
    if !field_history_is_running && !skip_field_history && get_changed_fields.present?
      raise ArgumentError.new('Value missing for field_history_user accessor') if field_history_user.blank?
    
      # Only update the field history revision if it hasn't been updated already.
      # There could've been an error in prior before_save, or the consuming model could want to specify a manual revision number.
      if !field_history_revision_changed?
        self.field_history_revision = (self.new_record?) ? 1 : (field_history_revision + 1)
      end
    end
  end

  # This checkes the standard rails field dirty methods to see what has changed on self, then builds the field history items.
  def build_field_history_items
    if !field_history_is_running && !skip_field_history
      changed_fields = get_changed_fields

      if changed_fields.present?
        self.field_history_is_running = true

        changed_fields.each do |field_item|
          field_name = field_item[:name]

          item = self.field_history_items.new(
            user_id: field_history_user.id,
            changed_at: updated_at,
            revision: field_history_revision,
            field: field_name,
            new_value: (field_item[:track_values] ? self[field_name] : nil),
            old_value: (field_item[:track_values] ? self.send("#{field_name}_was") : nil),
          )

          item.save
        end

        self.field_history_is_running = false
      end
    end
    
    true
  end

  def get_changed_fields
    self.class::fields.map do |field_name, field|
      {
        name: field_name,
        track_history: field.options[:metadata] && field.options[:metadata][:history_of].present?,
        track_values: field.options[:metadata] && (field.options[:metadata][:history_of] == :values),
      }
    end.select do |field_item|
      field_item[:track_history] && self.changed.include?(field_item[:name])  
    end
  end

end