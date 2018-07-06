class Doc < ApplicationRecord
  def self.search(search)
    where("name LIKE ? OR specialty LIKE ?", "%#{search}%", "%#{search}%")
  end
end
