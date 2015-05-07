# encoding: UTF-8
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20150506214105) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "reader_events", force: true do |t|
    t.integer  "reader_id"
    t.integer  "flow_number"
    t.string   "event"
    t.string   "tag_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "readers", force: true do |t|
    t.string   "name"
    t.string   "description"
    t.string   "mac_address"
    t.string   "version"
    t.string   "ip_address"
    t.string   "model"
    t.datetime "last_seen_at"
    t.boolean  "proceed_signal"
    t.boolean  "cancel_signal"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "action"
  end

  create_table "tags", force: true do |t|
    t.string   "tag_id"
    t.integer  "rssi"
    t.string   "antenna"
    t.datetime "last_seen_at"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "utid"
    t.integer  "reader_id"
    t.boolean  "visible"
    t.boolean  "funded"
    t.boolean  "member"
  end

end
