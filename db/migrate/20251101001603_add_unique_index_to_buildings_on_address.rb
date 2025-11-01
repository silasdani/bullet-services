class AddUniqueIndexToBuildingsOnAddress < ActiveRecord::Migration[8.0]
  def up
    # Remove duplicate buildings first (keep the oldest one, merge WRS to oldest building)
    execute <<-SQL
      UPDATE window_schedule_repairs wrs
      SET building_id = (
        SELECT b2.id
        FROM buildings b2
        WHERE LOWER(TRIM(b2.street)) = LOWER(TRIM((SELECT street FROM buildings WHERE id = wrs.building_id)))
          AND LOWER(TRIM(b2.city)) = LOWER(TRIM((SELECT city FROM buildings WHERE id = wrs.building_id)))
          AND LOWER(TRIM(COALESCE(b2.zipcode, ''))) = LOWER(TRIM(COALESCE((SELECT zipcode FROM buildings WHERE id = wrs.building_id), '')))
          AND b2.deleted_at IS NULL
        ORDER BY b2.id ASC
        LIMIT 1
      )
      WHERE wrs.building_id IN (
        SELECT b1.id
        FROM buildings b1
        WHERE b1.id > (
          SELECT MIN(b2.id)
          FROM buildings b2
          WHERE LOWER(TRIM(b1.street)) = LOWER(TRIM(b2.street))
            AND LOWER(TRIM(b1.city)) = LOWER(TRIM(b2.city))
            AND LOWER(TRIM(COALESCE(b1.zipcode, ''))) = LOWER(TRIM(COALESCE(b2.zipcode, '')))
            AND b1.deleted_at IS NULL
            AND b2.deleted_at IS NULL
        )
      );
    SQL

    execute <<-SQL
      DELETE FROM buildings b1
      USING buildings b2
      WHERE b1.id > b2.id
        AND LOWER(TRIM(b1.street)) = LOWER(TRIM(b2.street))
        AND LOWER(TRIM(b1.city)) = LOWER(TRIM(b2.city))
        AND LOWER(TRIM(COALESCE(b1.zipcode, ''))) = LOWER(TRIM(COALESCE(b2.zipcode, '')))
        AND b1.deleted_at IS NULL
        AND b2.deleted_at IS NULL;
    SQL

    # Add unique index on address fields (case-insensitive, nulls handled)
    execute <<-SQL
      CREATE UNIQUE INDEX index_buildings_on_unique_address
      ON buildings (LOWER(TRIM(street)), LOWER(TRIM(city)), LOWER(TRIM(COALESCE(zipcode, ''))))
      WHERE deleted_at IS NULL;
    SQL
  end

  def down
    remove_index :buildings, name: 'index_buildings_on_unique_address'
  end
end
