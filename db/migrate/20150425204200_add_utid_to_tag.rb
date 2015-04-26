class AddUtidToTag < ActiveRecord::Migration
  def change
    add_column :tags, :utid, :string
  end
end