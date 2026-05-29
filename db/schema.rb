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

ActiveRecord::Schema[8.1].define(version: 2026_05_29_000500) do
  create_table "audit_logs", force: :cascade do |t|
    t.string "action", null: false
    t.integer "auditable_id", null: false
    t.string "auditable_type", null: false
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.integer "membership_id", null: false
    t.json "metadata", default: {}, null: false
    t.integer "organization_id", null: false
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.index ["auditable_type", "auditable_id"], name: "index_audit_logs_on_auditable_type_and_auditable_id"
    t.index ["membership_id"], name: "index_audit_logs_on_membership_id"
    t.index ["organization_id", "created_at"], name: "index_audit_logs_on_organization_id_and_created_at"
    t.index ["organization_id"], name: "index_audit_logs_on_organization_id"
  end

  create_table "memberships", force: :cascade do |t|
    t.string "api_token_digest", null: false
    t.string "api_token_last_eight", null: false
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "full_name", null: false
    t.datetime "last_seen_at"
    t.integer "organization_id", null: false
    t.string "role", default: "agent", null: false
    t.string "state", default: "active", null: false
    t.datetime "updated_at", null: false
    t.index ["api_token_digest"], name: "index_memberships_on_api_token_digest", unique: true
    t.index ["organization_id", "email"], name: "index_memberships_on_organization_id_and_email", unique: true
    t.index ["organization_id", "role"], name: "index_memberships_on_organization_id_and_role"
    t.index ["organization_id"], name: "index_memberships_on_organization_id"
  end

  create_table "organizations", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "current_month_ticket_count", default: 0, null: false
    t.integer "inbox_limit", default: 2, null: false
    t.string "name", null: false
    t.integer "next_ticket_sequence", default: 1, null: false
    t.string "plan", default: "starter", null: false
    t.integer "seat_limit", default: 5, null: false
    t.string "slug", null: false
    t.string "state", default: "active", null: false
    t.integer "ticket_limit", default: 500, null: false
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_organizations_on_slug", unique: true
  end

  create_table "outbound_events", force: :cascade do |t|
    t.integer "aggregate_id", null: false
    t.string "aggregate_type", null: false
    t.integer "attempts_count", default: 0, null: false
    t.string "correlation_id", null: false
    t.datetime "created_at", null: false
    t.datetime "dispatched_at"
    t.string "event_type", null: false
    t.string "idempotency_key", null: false
    t.text "last_error"
    t.integer "organization_id", null: false
    t.json "payload", default: {}, null: false
    t.string "status", default: "pending", null: false
    t.datetime "updated_at", null: false
    t.index ["idempotency_key"], name: "index_outbound_events_on_idempotency_key", unique: true
    t.index ["organization_id", "status"], name: "index_outbound_events_on_organization_id_and_status"
    t.index ["organization_id"], name: "index_outbound_events_on_organization_id"
  end

  create_table "tickets", force: :cascade do |t|
    t.integer "assignee_membership_id"
    t.datetime "closed_at"
    t.datetime "created_at", null: false
    t.integer "created_by_membership_id", null: false
    t.text "description", null: false
    t.datetime "first_response_at"
    t.string "inbox", default: "general", null: false
    t.integer "lock_version", default: 0, null: false
    t.integer "organization_id", null: false
    t.string "priority", default: "normal", null: false
    t.string "public_id", null: false
    t.string "requester_email", null: false
    t.string "requester_name", null: false
    t.datetime "resolution_due_at"
    t.string "status", default: "open", null: false
    t.string "subject", null: false
    t.datetime "updated_at", null: false
    t.index ["assignee_membership_id"], name: "index_tickets_on_assignee_membership_id"
    t.index ["created_by_membership_id"], name: "index_tickets_on_created_by_membership_id"
    t.index ["organization_id", "public_id"], name: "index_tickets_on_organization_id_and_public_id", unique: true
    t.index ["organization_id", "requester_email"], name: "index_tickets_on_organization_id_and_requester_email"
    t.index ["organization_id", "status"], name: "index_tickets_on_organization_id_and_status"
    t.index ["organization_id"], name: "index_tickets_on_organization_id"
  end

  add_foreign_key "audit_logs", "memberships"
  add_foreign_key "audit_logs", "organizations"
  add_foreign_key "memberships", "organizations"
  add_foreign_key "outbound_events", "organizations"
  add_foreign_key "tickets", "memberships", column: "assignee_membership_id"
  add_foreign_key "tickets", "memberships", column: "created_by_membership_id"
  add_foreign_key "tickets", "organizations"
end
