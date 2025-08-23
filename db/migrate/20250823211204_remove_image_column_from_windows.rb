class RemoveImageColumnFromWindows < ActiveRecord::Migration[8.0]
  def change
    remove_column :windows, :image, :string
  end
end
