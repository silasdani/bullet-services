# frozen_string_literal: true

class RemoveWebflowFields < ActiveRecord::Migration[8.0]
  def up
    # Remove Webflow fields from window_schedule_repairs
    remove_column :window_schedule_repairs, :webflow_item_id, :string if column_exists?(:window_schedule_repairs, :webflow_item_id)
    remove_column :window_schedule_repairs, :webflow_main_image_url, :string if column_exists?(:window_schedule_repairs, :webflow_main_image_url)
    remove_column :window_schedule_repairs, :sitemap_on, :boolean if column_exists?(:window_schedule_repairs, :sitemap_on)
    remove_column :window_schedule_repairs, :last_published, :datetime if column_exists?(:window_schedule_repairs, :last_published)

    # Remove Webflow fields from windows
    remove_column :windows, :webflow_image_url, :string if column_exists?(:windows, :webflow_image_url)

    # Remove Webflow fields from invoices
    remove_column :invoices, :webflow_item_id, :string if column_exists?(:invoices, :webflow_item_id)
    remove_column :invoices, :webflow_collection_id, :string if column_exists?(:invoices, :webflow_collection_id)
    remove_column :invoices, :webflow_created_on, :string if column_exists?(:invoices, :webflow_created_on)
    remove_column :invoices, :webflow_published_on, :string if column_exists?(:invoices, :webflow_published_on)
    remove_column :invoices, :webflow_updated_on, :string if column_exists?(:invoices, :webflow_updated_on)
  end

  def down
    # Restore Webflow fields (if needed for rollback)
    add_column :window_schedule_repairs, :webflow_item_id, :string
    add_column :window_schedule_repairs, :webflow_main_image_url, :string
    add_column :window_schedule_repairs, :sitemap_on, :boolean
    add_column :window_schedule_repairs, :last_published, :datetime

    add_column :windows, :webflow_image_url, :string

    add_column :invoices, :webflow_item_id, :string
    add_column :invoices, :webflow_collection_id, :string
    add_column :invoices, :webflow_created_on, :string
    add_column :invoices, :webflow_published_on, :string
    add_column :invoices, :webflow_updated_on, :string
  end
end
