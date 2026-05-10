class CreatePosts < ActiveRecord::Migration[8.0]
  def up
    create_document_strict :posts do |t|
      t.column :id,    "TEXT PRIMARY KEY"
      t.column :title, :text
      t.column :body,  :text
    end
  end

  def down
    drop_collection :posts, if_exists: true
  end
end
