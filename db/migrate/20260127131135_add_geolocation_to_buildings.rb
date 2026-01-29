class AddGeolocationToBuildings < ActiveRecord::Migration[8.0]
  def up
    add_column :buildings, :latitude, :decimal, precision: 10, scale: 7
    add_column :buildings, :longitude, :decimal, precision: 10, scale: 7

    # Index for distance queries
    add_index :buildings, [:latitude, :longitude]

    # Geocode existing buildings in background
    Building.reset_column_information
    Building.find_each do |building|
      Buildings::GeocodeJob.perform_later(building.id)
    end
  end

  def down
    remove_index :buildings, [:latitude, :longitude]
    remove_column :buildings, :longitude
    remove_column :buildings, :latitude
  end
end
