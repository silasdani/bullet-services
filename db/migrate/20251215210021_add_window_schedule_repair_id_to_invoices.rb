class AddWindowScheduleRepairIdToInvoices < ActiveRecord::Migration[8.0]
  def change
    add_column :invoices, :window_schedule_repair_id, :bigint
    add_index :invoices, :window_schedule_repair_id
    add_foreign_key :invoices, :window_schedule_repairs
  end
end
