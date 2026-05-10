class CreateArticles < ActiveRecord::Migration[8.0]
  def up
    create_document_strict :articles do |t|
      t.column :id,    "TEXT PRIMARY KEY"
      t.column :title, :text
      t.column :body,  :text
    end
  end

  def down
    drop_collection :articles, if_exists: true
  end
end
