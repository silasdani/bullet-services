# frozen_string_literal: true

class AddAutoCheckoutToTimeEntries < ActiveRecord::Migration[7.2]
  def change
    add_column :time_entries, :auto_checkout, :boolean, default: false, null: false
  end
end
