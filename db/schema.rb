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

ActiveRecord::Schema.define(version: 20190716144900) do

  create_table "BigQueryJobStats", id: :string, limit: 36, force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=latin1" do |t|
    t.string "user_id", null: false
    t.string "job_group_id", null: false
    t.bigint "created_at", null: false
    t.bigint "ended_at", null: false
    t.datetime "recorded_at", null: false
    t.bigint "started_at", null: false
    t.string "query_cache", null: false
    t.bigint "query_total_bytes_billed", null: false
    t.bigint "query_total_bytes_processed", null: false
    t.index ["user_id", "job_group_id"], name: "index_BigQueryJobStats_on_user_id_and_job_group_id"
    t.index ["user_id"], name: "index_BigQueryJobStats_on_user_id"
  end

  create_table "ReleaseNoteReadReceipts", id: :string, limit: 36, force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=latin1" do |t|
    t.string "user_id", null: false
    t.string "entry_id", null: false
    t.datetime "created_at"
    t.index ["created_at"], name: "index_ReleaseNoteReadReceipts_on_created_at"
    t.index ["user_id", "entry_id"], name: "index_ReleaseNoteReadReceipts_on_user_id_and_entry_id", unique: true
    t.index ["user_id"], name: "index_ReleaseNoteReadReceipts_on_user_id"
  end

  create_table "searches", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4" do |t|
    t.bigint "user_id"
    t.string "name"
    t.string "type"
    t.boolean "saved"
    t.text "parameters"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_searches_on_user_id"
  end

  create_table "users", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4" do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer "sign_in_count", default: 0, null: false
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string "current_sign_in_ip"
    t.string "last_sign_in_ip"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "provider"
    t.string "uid"
    t.string "token"
    t.integer "expires_at"
    t.boolean "expires"
    t.string "refresh_token"
    t.integer "role"
    t.text "preferences"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "searches", "users"
end
