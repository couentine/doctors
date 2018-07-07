class Doc < ApplicationRecord
  def self.search(search)
    where("name ILIKE ? OR specialty ILIKE ?", "%#{search.downcase}%", "%#{search.downcase}%")
  end
end
