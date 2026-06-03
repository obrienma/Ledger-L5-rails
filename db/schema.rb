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

ActiveRecord::Schema[8.1].define(version: 2026_06_03_212932) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "api_keys", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.uuid "tenant_id", null: false
    t.string "token_digest", null: false
    t.datetime "updated_at", null: false
    t.index ["tenant_id"], name: "index_api_keys_on_tenant_id"
  end

  create_table "entitlements", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.uuid "tenant_id", null: false
    t.boolean "throttled", default: false, null: false
    t.datetime "throttled_at"
    t.datetime "updated_at", null: false
    t.index ["tenant_id"], name: "index_entitlements_on_tenant_id", unique: true
  end

  create_table "invoices", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.integer "amount_cents", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "paid_at"
    t.date "period_end", null: false
    t.date "period_start", null: false
    t.string "status", default: "draft", null: false
    t.string "stripe_invoice_id"
    t.uuid "tenant_id", null: false
    t.datetime "updated_at", null: false
    t.index ["stripe_invoice_id"], name: "index_invoices_on_stripe_invoice_id", unique: true, where: "(stripe_invoice_id IS NOT NULL)"
    t.index ["tenant_id"], name: "index_invoices_on_tenant_id"
  end

  create_table "operators", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_operators_on_email", unique: true
    t.index ["reset_password_token"], name: "index_operators_on_reset_password_token", unique: true
  end

  create_table "tenant_balances", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.decimal "current_usage", precision: 12, scale: 4, default: "0.0", null: false
    t.date "period_end", null: false
    t.date "period_start", null: false
    t.uuid "tenant_id", null: false
    t.datetime "updated_at", null: false
    t.index ["tenant_id"], name: "index_tenant_balances_on_tenant_id", unique: true
  end

  create_table "tenants", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.string "plan", default: "free", null: false
    t.string "status", default: "active", null: false
    t.string "stripe_customer_id"
    t.datetime "updated_at", null: false
  end

  create_table "usage_events", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "event_type", null: false
    t.string "idempotency_key", null: false
    t.jsonb "metadata", default: {}, null: false
    t.datetime "occurred_at", null: false
    t.decimal "quantity", precision: 12, scale: 4, null: false
    t.uuid "tenant_id", null: false
    t.datetime "updated_at", null: false
    t.index ["idempotency_key"], name: "index_usage_events_on_idempotency_key", unique: true
    t.index ["occurred_at"], name: "index_usage_events_on_occurred_at"
    t.index ["tenant_id"], name: "index_usage_events_on_tenant_id"
  end

  add_foreign_key "api_keys", "tenants"
  add_foreign_key "entitlements", "tenants"
  add_foreign_key "invoices", "tenants"
  add_foreign_key "tenant_balances", "tenants"
  add_foreign_key "usage_events", "tenants"
end
