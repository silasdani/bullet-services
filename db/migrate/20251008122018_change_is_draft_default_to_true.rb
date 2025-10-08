class ChangeIsDraftDefaultToTrue < ActiveRecord::Migration[8.0]
  def change
    change_column_default :window_schedule_repairs, :is_draft, from: false, to: true
  end
end
