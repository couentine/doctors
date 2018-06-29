class Doc < ApplicationRecord
  def self.search(search)
    where("name LIKE ? OR specialty LIKE ? OR zip LIKE ? OR review LIKE ?", "%#{search}%", "%#{search}%", "%#{search}%", "%#{search}%")
  end
end
