# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 7) do
  create_document_strict "articles" do |t|
    t.column :id, "TEXT PRIMARY KEY"
    t.column :title, "text"
    t.column :body, "text"
  end

  create_spatial "b011_1779080516" do |t|
    t.column :id, "TEXT PRIMARY KEY"
    t.column :geom, "GEOMETRY"
  end

  create_collection "embeddings" do |t|
    t.column :document, "JSON"
  end

  create_kv "kv_sessions" do |t|
    t.column :key, "TEXT PRIMARY KEY"
    t.column :value, "text"
  end

  create_document_strict "locations" do |t|
    t.column :id, "TEXT PRIMARY KEY"
    t.column :name, "text"
    t.column :lat, "float"
    t.column :lon, "float"
  end

  create_timeseries "metrics" do |t|
    t.column :ts, "TIMESTAMP TIME_KEY"
    t.column :host, "text"
    t.column :value, "float"
  end

  create_document_strict "posts" do |t|
    t.column :id, "TEXT PRIMARY KEY"
    t.column :title, "text"
    t.column :body, "text"
  end

  create_collection "social_nodes" do |t|
    t.column :document, "JSON"
  end

end
