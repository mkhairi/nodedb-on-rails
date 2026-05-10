class CreateLocations < ActiveRecord::Migration[8.0]
  def up
    # NodeDB's spatial engine drops typed columns (BUG-012) and ignores
    # ST_GeomFromText on INSERT (BUG-011), so the sample app stores plain
    # lat/lon and computes haversine in Ruby. Use document_strict.
    create_document_strict :locations do |t|
      t.column :id,   "TEXT PRIMARY KEY"
      t.column :name, :text
      t.column :lat,  :float
      t.column :lon,  :float
    end
  end

  def down
    drop_collection :locations, if_exists: true
  end
end
