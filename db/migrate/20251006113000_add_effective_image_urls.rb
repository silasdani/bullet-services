class AddEffectiveImageUrls < ActiveRecord::Migration[8.0]
  def change
    add_column :window_schedule_repairs, :effective_main_image_url, :string
    add_column :windows, :effective_image_url, :string
  end
end


