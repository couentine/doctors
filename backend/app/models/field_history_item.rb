#==========================================================================================================================================#
# 
# FIELD HISTORY ITEM MODEL
# 
# Polymorphic embedded document.
# Implemented by the FieldHistory module. 
# Refer to `modules/field_history.rb` for docs.
# 
#==========================================================================================================================================#

class FieldHistoryItem
  include Mongoid::Document
  include Mongoid::Timestamps

  # === RELATIONSHIPS === #

  embedded_in :field_history_list,        polymorphic: true

  # === FIELDS === #

  field :user_id,                         type: BSON::ObjectId
  field :revision,                        type: Integer
  field :changed_at,                      type: DateTime

  field :field,                           type: String
  field :old_value,                       type: String
  field :new_value,                       type: String

  # === VALIDATIONS === #

  validates :user_id,                     presence: true
  validates :changed_at,                  presence: true
  validates :field,                       presence: true
  
  # === INSTANCE METHODS === #

  def user
    User.find(user_id) rescue nil
  end

  def to_h
    {
      revision: revision,
      changed_at: changed_at,
      user_id: user_id,
      field: field,
      old_value: old_value,
      new_value: new_value,
    }
  end

  def to_s
    to_h.to_s
  end

end