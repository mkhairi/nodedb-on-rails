class CreatePosts < ActiveRecord::Migration[8.0]
  def up
    create_fts :posts, fulltext: [:body] do |t|
      t.column :id,    "TEXT PRIMARY KEY"
      t.column :title, :text
      t.column :body,  :text
    end
  end

  def down
    drop_collection :posts, if_exists: true
  end
end
