class CreateMetrics < ActiveRecord::Migration[8.0]
  def up
    create_timeseries :metrics do |t|
      t.column :ts,    "TIMESTAMP TIME_KEY"
      t.column :host,  :text
      t.column :value, :float
    end
  end

  def down
    drop_collection :metrics, if_exists: true
  end
end
