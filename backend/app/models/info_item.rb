class InfoItem
  include Mongoid::Document
  include Mongoid::Timestamps
  
  # === RELATIONSHIPS === #

  belongs_to :user
  belongs_to :group

  # === FIELDS & VALIDATIONS === #

  field :type,        type: String
  field :name,        type: String # optional, acts as a label
  field :key,         type: String # optional, must be unique
  field :data,        type: Hash, default: {}, pre_processed: true
  field :delete_at,   type: Time # set this to automatically delete this item at a future time

  validates :key, uniqueness: { scope: :type }, allow_blank: true

  # === CALLBACK === #

  after_save :queue_delete_if_needed

  # === CLASS METHODS === #

  def self.delete_info_item(info_item_id)
    info_item = InfoItem.find(info_item_id) rescue nil
    info_item.delete if info_item
  end

protected

  def queue_delete_if_needed
    InfoItem.delay_until(delete_at).delete_info_item(id.to_s) if delete_at
  end

end
