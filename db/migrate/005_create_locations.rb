class CreateLocations < ActiveRecord::Migration[8.0]
  def up
    # The sample app stores plain lat/lon and computes haversine in
    # Ruby rather than leaning on the spatial engine, which was unusable
    # for most of the alpha. Use document_strict.
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
