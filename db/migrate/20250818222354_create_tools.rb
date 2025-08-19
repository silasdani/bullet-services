class CreateTools < ActiveRecord::Migration[8.0]
  def change
    create_table :tools do |t|
      t.string :name
      t.integer :price
      t.references :window, null: false, foreign_key: true

      t.timestamps
    end
  end
end
