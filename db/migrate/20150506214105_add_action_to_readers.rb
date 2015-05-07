class AddActionToReaders < ActiveRecord::Migration
  def change
    add_column :readers, :action, :string
  end
end