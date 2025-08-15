class CreateWindowScheduleRepairs < ActiveRecord::Migration[8.0]
  def change
    create_table :window_schedule_repairs do |t|
      t.string :name
      t.string :slug
      t.string :flat_number
      t.string :reference_number
      t.string :address
      t.integer :total_included_vat
      t.integer :total_excluded_vat
      t.string :status_color
      t.integer :status
      t.boolean :sitemap_on
      t.string :webflow_item_id
      t.string :webflow_collection_id

      t.timestamps
    end
  end
end
