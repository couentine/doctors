class Badge
  include Mongoid::Document
  field :name, type: String
  field :image_url, type: String
  field :summary, type: String
  field :description, type: String
end
