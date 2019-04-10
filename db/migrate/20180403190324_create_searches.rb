class CreateSearches < ActiveRecord::Migration[5.1]
  def change
    create_table :searches do |t|
      t.references :user, foreign_key: true
      t.string :name
      t.string :type
      t.boolean :saved
      t.text :parameters

      t.timestamps
    end
  end
end
