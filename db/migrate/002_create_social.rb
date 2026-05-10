class CreateSocial < ActiveRecord::Migration[8.0]
  def up
    create_collection :social_nodes
  end

  def down
    drop_collection :social_nodes, if_exists: true
  end
end
