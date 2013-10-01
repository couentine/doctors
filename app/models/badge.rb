class Badge
  include Mongoid::Document
  include Mongoid::Timestamps

  # Constants
  
  MAX_NAME_LENGTH = 50
  MAX_SUMMARY_LENGTH = 140

  # Fields & Validations

  field :name, type: String
  field :image_url, type: String
  field :summary, type: String
  field :description, type: String

  validates :name, presence: true, length: { maximum: MAX_NAME_LENGTH }
  validates :image_url, presence: true
  validates :summary, presence: true, length: { maximum: MAX_SUMMARY_LENGTH }
  validates :description, presence: true

end