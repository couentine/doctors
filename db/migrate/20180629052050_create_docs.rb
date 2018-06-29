class CreateDocs < ActiveRecord::Migration[5.1]
  def change
    create_table :docs do |t|
      t.string :name
      t.string :specialty
      t.integer :zip
      t.integer :review

      t.timestamps
    end
  end
end
