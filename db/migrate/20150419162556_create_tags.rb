class CreateTags < ActiveRecord::Migration
  def change
    create_table :tags do |t|
      t.string :tag_id
      t.integer :rssi
      t.string :antenna
      t.datetime :last_seen_at

      t.timestamps
    end
  end
end
