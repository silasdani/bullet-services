 # frozen_string_literal: true

 class AddBuildingIdToTimeEntries < ActiveRecord::Migration[8.0]
   disable_ddl_transaction!

   def up
     add_reference :time_entries, :building, null: true, index: false

     add_index :time_entries, %i[building_id starts_at], algorithm: :concurrently

     backfill_building_id

     change_column_null :time_entries, :building_id, false

     add_foreign_key :time_entries, :buildings
   end

   def down
     remove_foreign_key :time_entries, :buildings

     remove_index :time_entries, column: %i[building_id starts_at]

     remove_reference :time_entries, :building
   end

   private

   def backfill_building_id
     say_with_time 'Backfilling time_entries.building_id from work_orders.building_id' do
       execute <<~SQL.squish
         UPDATE time_entries te
         SET building_id = wo.building_id
         FROM work_orders wo
         WHERE te.work_order_id = wo.id
           AND te.building_id IS NULL
       SQL
     end
   end
 end
