# frozen_string_literal: true

class RemoveDuplicateWorkOrderForeignKeys < ActiveRecord::Migration[8.0]
  TABLES_WITH_WORK_ORDER_FK = %w[check_ins notifications ongoing_works windows work_order_decisions work_sessions].freeze

  def up
    TABLES_WITH_WORK_ORDER_FK.each do |table|
      remove_duplicate_work_order_foreign_keys(table)
    end

    # work_orders -> buildings and work_orders -> users may also have duplicates
    remove_duplicate_foreign_keys('work_orders', 'building_id')
    remove_duplicate_foreign_keys('work_orders', 'user_id')
  end

  def down
    # Irreversible - we're cleaning up duplicates; rollback would require knowing original state
  end

  private

  def remove_duplicate_work_order_foreign_keys(table)
    work_order_fks = connection.foreign_keys(table).select { |fk| fk.column == 'work_order_id' }
    work_order_fks.drop(1).each do |fk|
      remove_foreign_key table, name: fk.name
    end
  end

  def remove_duplicate_foreign_keys(table, column)
    fks = connection.foreign_keys(table).select { |fk| fk.column == column }
    fks.drop(1).each do |fk|
      remove_foreign_key table, name: fk.name
    end
  end
end
