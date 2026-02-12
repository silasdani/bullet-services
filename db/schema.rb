# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2026_02_12_000001) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "buildings", force: :cascade do |t|
    t.string "name"
    t.string "street"
    t.string "city"
    t.string "country"
    t.string "zipcode"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "deleted_at"
    t.decimal "latitude", precision: 10, scale: 7
    t.decimal "longitude", precision: 10, scale: 7
    t.index "lower(TRIM(BOTH FROM street)), lower(TRIM(BOTH FROM city)), lower(TRIM(BOTH FROM COALESCE(zipcode, ''::character varying)))", name: "index_buildings_on_unique_address", unique: true, where: "(deleted_at IS NULL)"
    t.index ["deleted_at"], name: "index_buildings_on_deleted_at"
    t.index ["latitude", "longitude"], name: "index_buildings_on_latitude_and_longitude"
    t.index ["name"], name: "index_buildings_on_name"
    t.index ["street", "city", "zipcode"], name: "index_buildings_on_address_fields"
  end

  create_table "check_ins", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "work_order_id", null: false
    t.integer "action", null: false
    t.decimal "latitude", precision: 10, scale: 7
    t.decimal "longitude", precision: 10, scale: 7
    t.string "address"
    t.datetime "timestamp", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "lock_version", default: 0, null: false
    t.datetime "deleted_at"
    t.index ["deleted_at"], name: "index_check_ins_on_deleted_at"
    t.index ["timestamp"], name: "index_check_ins_on_timestamp"
    t.index ["user_id", "work_order_id", "action"], name: "index_check_ins_on_user_id_and_work_order_id_and_action"
    t.index ["user_id"], name: "index_check_ins_on_user_id"
    t.index ["work_order_id", "action", "timestamp"], name: "index_check_ins_on_wrs_action_timestamp"
    t.index ["work_order_id"], name: "index_check_ins_on_work_order_id"
  end

  create_table "freshbooks_clients", force: :cascade do |t|
    t.string "freshbooks_id"
    t.string "email"
    t.string "first_name"
    t.string "last_name"
    t.string "organization"
    t.string "phone"
    t.text "address"
    t.string "city"
    t.string "province"
    t.string "postal_code"
    t.string "country"
    t.jsonb "raw_data"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_freshbooks_clients_on_email"
    t.index ["freshbooks_id"], name: "index_freshbooks_clients_on_freshbooks_id", unique: true
  end

  create_table "freshbooks_invoices", force: :cascade do |t|
    t.string "freshbooks_id", null: false
    t.string "freshbooks_client_id", null: false
    t.string "invoice_number"
    t.string "status"
    t.decimal "amount", precision: 10, scale: 2
    t.decimal "amount_outstanding", precision: 10, scale: 2
    t.date "date"
    t.date "due_date"
    t.string "currency_code"
    t.text "notes"
    t.string "pdf_url"
    t.jsonb "raw_data"
    t.bigint "invoice_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["freshbooks_client_id"], name: "index_freshbooks_invoices_on_freshbooks_client_id"
    t.index ["freshbooks_id"], name: "index_freshbooks_invoices_on_freshbooks_id", unique: true
    t.index ["invoice_id"], name: "index_freshbooks_invoices_on_invoice_id"
    t.index ["status"], name: "index_freshbooks_invoices_on_status"
  end

  create_table "freshbooks_payments", force: :cascade do |t|
    t.string "freshbooks_id", null: false
    t.string "freshbooks_invoice_id", null: false
    t.decimal "amount", precision: 10, scale: 2, null: false
    t.date "date", null: false
    t.string "payment_method"
    t.string "currency_code"
    t.text "notes"
    t.jsonb "raw_data"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["date"], name: "index_freshbooks_payments_on_date"
    t.index ["freshbooks_id"], name: "index_freshbooks_payments_on_freshbooks_id", unique: true
    t.index ["freshbooks_invoice_id"], name: "index_freshbooks_payments_on_freshbooks_invoice_id"
  end

  create_table "freshbooks_tokens", force: :cascade do |t|
    t.text "access_token", null: false
    t.text "refresh_token", null: false
    t.datetime "token_expires_at", null: false
    t.string "business_id", null: false
    t.string "user_freshbooks_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["business_id"], name: "index_freshbooks_tokens_on_business_id", unique: true
  end

  create_table "invoices", force: :cascade do |t|
    t.string "name"
    t.string "slug"
    t.boolean "is_archived"
    t.boolean "is_draft"
    t.string "freshbooks_client_id"
    t.string "job"
    t.string "wrs_link"
    t.decimal "included_vat_amount"
    t.decimal "excluded_vat_amount"
    t.string "status_color"
    t.string "status"
    t.string "final_status"
    t.string "invoice_pdf_link"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "flat_address"
    t.string "generated_by"
    t.bigint "work_order_id"
    t.datetime "deleted_at"
    t.index ["deleted_at"], name: "index_invoices_on_deleted_at"
    t.index ["slug"], name: "index_invoices_on_slug"
    t.index ["work_order_id"], name: "index_invoices_on_work_order_id"
    t.check_constraint "excluded_vat_amount >= 0::numeric", name: "invoices_excluded_vat_non_negative"
    t.check_constraint "included_vat_amount >= 0::numeric", name: "invoices_included_vat_non_negative"
  end

  create_table "notifications", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "work_order_id"
    t.integer "notification_type", null: false
    t.string "title", null: false
    t.text "message"
    t.jsonb "metadata"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "read_at"
    t.datetime "deleted_at"
    t.index ["created_at"], name: "index_notifications_on_created_at"
    t.index ["deleted_at"], name: "index_notifications_on_deleted_at"
    t.index ["read_at"], name: "index_notifications_on_read_at"
    t.index ["user_id", "created_at"], name: "index_notifications_on_user_unread", where: "(read_at IS NULL)"
    t.index ["user_id", "read_at", "created_at"], name: "index_notifications_on_user_read_created"
    t.index ["user_id"], name: "index_notifications_on_user_id"
    t.index ["work_order_id", "notification_type"], name: "index_notifications_on_wrs_type"
    t.index ["work_order_id"], name: "index_notifications_on_work_order_id"
  end

  create_table "ongoing_works", force: :cascade do |t|
    t.bigint "work_order_id", null: false
    t.bigint "user_id", null: false
    t.text "description"
    t.datetime "work_date", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "deleted_at"
    t.index ["deleted_at"], name: "index_ongoing_works_on_deleted_at"
    t.index ["user_id"], name: "index_ongoing_works_on_user_id"
    t.index ["work_order_id", "work_date", "user_id"], name: "index_ongoing_works_on_wrs_date_user"
    t.index ["work_order_id", "work_date"], name: "index_ongoing_works_on_work_order_id_and_work_date"
    t.index ["work_order_id"], name: "index_ongoing_works_on_work_order_id"
  end

  create_table "price_snapshots", force: :cascade do |t|
    t.string "priceable_type", null: false
    t.bigint "work_order_id", null: false
    t.decimal "subtotal", precision: 10, scale: 2
    t.decimal "vat_rate", precision: 5, scale: 4
    t.decimal "vat_amount", precision: 10, scale: 2
    t.decimal "total", precision: 10, scale: 2
    t.datetime "snapshot_at", null: false
    t.jsonb "line_items"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "deleted_at"
    t.index ["deleted_at"], name: "index_price_snapshots_on_deleted_at"
    t.index ["priceable_type", "work_order_id", "snapshot_at"], name: "index_price_snapshots_on_priceable_and_time"
    t.index ["priceable_type", "work_order_id"], name: "index_price_snapshots_on_priceable"
    t.index ["snapshot_at"], name: "index_price_snapshots_on_snapshot_at"
  end

  create_table "status_definitions", force: :cascade do |t|
    t.string "entity_type", null: false
    t.string "status_key", null: false
    t.string "status_label", null: false
    t.string "status_color", null: false
    t.integer "display_order", default: 0
    t.boolean "is_active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["entity_type", "is_active", "display_order"], name: "index_status_definitions_on_entity_active_order"
    t.index ["entity_type", "status_key"], name: "index_status_definitions_on_entity_and_key", unique: true
  end

  create_table "tools", force: :cascade do |t|
    t.string "name", null: false
    t.decimal "price", precision: 10, scale: 2, default: "0.0", null: false
    t.bigint "window_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "deleted_at"
    t.index ["deleted_at"], name: "index_tools_on_deleted_at"
    t.index ["window_id"], name: "index_tools_on_window_id"
    t.check_constraint "price >= 0::numeric", name: "tools_price_non_negative"
  end

  create_table "users", force: :cascade do |t|
    t.string "provider", default: "email", null: false
    t.string "uid", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.boolean "allow_password_change", default: false
    t.datetime "remember_created_at"
    t.string "confirmation_token"
    t.datetime "confirmed_at"
    t.datetime "confirmation_sent_at"
    t.string "unconfirmed_email"
    t.string "nickname"
    t.string "image"
    t.string "email"
    t.json "tokens"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "role", default: 0, null: false
    t.boolean "webflow_access", default: false
    t.datetime "deleted_at"
    t.boolean "blocked", default: false, null: false
    t.string "fcm_token"
    t.string "first_name"
    t.string "last_name"
    t.string "phone_no"
    t.index ["blocked"], name: "index_users_on_blocked"
    t.index ["confirmation_token"], name: "index_users_on_confirmation_token", unique: true
    t.index ["deleted_at"], name: "index_users_on_deleted_at"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["fcm_token"], name: "index_users_on_fcm_token", where: "(fcm_token IS NOT NULL)"
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["uid", "provider"], name: "index_users_on_uid_and_provider", unique: true
  end

  create_table "windows", force: :cascade do |t|
    t.string "location", null: false
    t.bigint "work_order_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "deleted_at"
    t.index ["deleted_at"], name: "index_windows_on_deleted_at"
    t.index ["work_order_id"], name: "index_windows_on_work_order_id"
  end

  create_table "work_order_assignments", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "work_order_id", null: false
    t.bigint "assigned_by_user_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["assigned_by_user_id"], name: "index_work_order_assignments_on_assigned_by_user_id"
    t.index ["user_id", "work_order_id"], name: "index_work_order_assignments_on_user_id_and_work_order_id", unique: true
    t.index ["user_id"], name: "index_work_order_assignments_on_user_id"
    t.index ["work_order_id"], name: "index_work_order_assignments_on_work_order_id"
  end

  create_table "work_order_decisions", force: :cascade do |t|
    t.bigint "work_order_id", null: false
    t.string "decision", null: false
    t.datetime "decision_at", null: false
    t.string "client_email"
    t.string "client_name"
    t.datetime "terms_accepted_at"
    t.string "terms_version"
    t.jsonb "decision_metadata"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "deleted_at"
    t.index ["decision_at"], name: "index_work_order_decisions_on_decision_at"
    t.index ["deleted_at"], name: "index_work_order_decisions_on_deleted_at"
    t.index ["work_order_id"], name: "index_work_order_decisions_on_work_order_id", unique: true
  end

  create_table "work_orders", force: :cascade do |t|
    t.string "name", null: false
    t.string "slug"
    t.string "flat_number"
    t.string "reference_number"
    t.decimal "total_vat_included_price", precision: 10, scale: 2
    t.decimal "total_vat_excluded_price", precision: 10, scale: 2
    t.string "status_color"
    t.integer "status"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.text "details"
    t.datetime "deleted_at"
    t.boolean "is_draft", default: true, null: false
    t.boolean "is_archived", default: false, null: false
    t.bigint "building_id", null: false
    t.integer "work_type", default: 0, null: false
    t.index ["building_id", "status", "deleted_at"], name: "index_wrs_on_building_status_deleted"
    t.index ["building_id"], name: "index_work_orders_on_building_id"
    t.index ["deleted_at"], name: "index_work_orders_on_deleted_at"
    t.index ["slug"], name: "index_work_orders_on_slug", unique: true
    t.index ["status"], name: "index_work_orders_on_status"
    t.index ["status"], name: "index_wrs_on_status_active", where: "((deleted_at IS NULL) AND (is_draft = false))"
    t.index ["user_id", "status", "created_at"], name: "index_wrs_on_user_status_created"
    t.index ["user_id"], name: "index_work_orders_on_user_id"
    t.index ["work_type"], name: "index_work_orders_on_work_type"
    t.check_constraint "total_vat_excluded_price >= 0::numeric", name: "wrs_total_vat_excluded_non_negative"
    t.check_constraint "total_vat_included_price >= 0::numeric", name: "wrs_total_vat_included_non_negative"
  end

  create_table "work_sessions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "work_order_id", null: false
    t.datetime "checked_in_at", null: false
    t.datetime "checked_out_at"
    t.decimal "latitude", precision: 10, scale: 7
    t.decimal "longitude", precision: 10, scale: 7
    t.string "address"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "deleted_at"
    t.index ["checked_in_at"], name: "index_work_sessions_on_checked_in_at"
    t.index ["deleted_at"], name: "index_work_sessions_on_deleted_at"
    t.index ["user_id", "work_order_id", "checked_out_at"], name: "index_work_sessions_on_user_wrs_checked_out"
    t.index ["user_id"], name: "index_work_sessions_on_user_id"
    t.index ["work_order_id", "checked_in_at"], name: "index_work_sessions_on_work_order_id_and_checked_in_at"
    t.index ["work_order_id"], name: "index_work_sessions_on_work_order_id"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "check_ins", "users"
  add_foreign_key "check_ins", "work_orders"
  add_foreign_key "invoices", "work_orders"
  add_foreign_key "notifications", "users"
  add_foreign_key "notifications", "work_orders"
  add_foreign_key "ongoing_works", "users"
  add_foreign_key "ongoing_works", "work_orders"
  add_foreign_key "tools", "windows"
  add_foreign_key "windows", "work_orders"
  add_foreign_key "work_order_assignments", "users"
  add_foreign_key "work_order_assignments", "users", column: "assigned_by_user_id"
  add_foreign_key "work_order_assignments", "work_orders"
  add_foreign_key "work_order_decisions", "work_orders"
  add_foreign_key "work_orders", "buildings"
  add_foreign_key "work_orders", "users"
  add_foreign_key "work_sessions", "users"
  add_foreign_key "work_sessions", "work_orders"
end
