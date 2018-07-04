class Doc < ApplicationRecord
  def self.search(search)
    where("name LIKE ? OR specialty LIKE ? OR zip = ? OR review = ?", "%#{search}%", "%#{search}%", "%#{search}%", "%#{search}%")
  end
end
