class Doc < ApplicationRecord
  def self.search(search)
    where("name LIKE ? OR specialty LIKE ?", "%#{search.downcase}%", "%#{search.downcase}%")
  end
end
