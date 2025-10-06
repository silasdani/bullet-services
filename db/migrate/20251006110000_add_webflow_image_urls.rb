class AddWebflowImageUrls < ActiveRecord::Migration[8.0]
  def change
    add_column :window_schedule_repairs, :webflow_main_image_url, :string
    add_column :windows, :webflow_image_url, :string
  end
end
