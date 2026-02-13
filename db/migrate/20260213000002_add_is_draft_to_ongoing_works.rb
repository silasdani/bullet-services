# frozen_string_literal: true

class AddIsDraftToOngoingWorks < ActiveRecord::Migration[8.0]
  def change
    add_column :ongoing_works, :is_draft, :boolean, default: true, null: false
  end
end
