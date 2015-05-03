class CreateReaders < ActiveRecord::Migration
  def change
    create_table :readers do |t|
      t.string :name
      t.string :description
      t.string :mac_address
      t.string :version # readertype Alien RFID Tag Reader, Model: ALR-9650 (One Antenna / Gen 2 / 902-928 MHz)
      t.string :ip_address
      t.string :model
      t.datetime :last_seen_at
      t.boolean :proceed_signal
      t.boolean :cancel_signal
      t.timestamps
    end
    
    create_table :reader_events do |t|
      t.integer :reader_id
      t.integer :flow_number
      t.string :event      
      t.string :tag_id
      t.timestamps
    end

    add_column :tags, :reader_id, :integer
    add_column :tags, :visible, :boolean
    add_column :tags, :funded,  :boolean
    add_column :tags, :member,  :boolean
  end
end

