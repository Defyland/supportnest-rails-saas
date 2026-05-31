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

ActiveRecord::Schema[8.1].define(version: 2026_05_31_120000) do
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
    t.datetime "api_token_expires_at", null: false
    t.string "api_token_last_eight", null: false
    t.datetime "api_token_revoked_at"
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "full_name", null: false
    t.datetime "last_seen_at"
    t.integer "organization_id", null: false
    t.string "role", default: "agent", null: false
    t.string "state", default: "active", null: false
    t.datetime "updated_at", null: false
    t.index ["api_token_digest"], name: "index_memberships_on_api_token_digest", unique: true
    t.index ["api_token_expires_at"], name: "index_memberships_on_api_token_expires_at"
    t.index ["organization_id", "email"], name: "index_memberships_on_organization_id_and_email", unique: true
    t.index ["organization_id", "role"], name: "index_memberships_on_organization_id_and_role"
    t.index ["organization_id"], name: "index_memberships_on_organization_id"
    t.check_constraint "api_token_expires_at > created_at", name: "memberships_api_token_expires_after_creation"
    t.check_constraint "api_token_revoked_at IS NULL OR api_token_revoked_at >= created_at", name: "memberships_api_token_revoked_after_creation"
    t.check_constraint "length(api_token_last_eight) = 8", name: "memberships_token_last_eight_length"
    t.check_constraint "role IN ('owner', 'admin', 'agent', 'viewer')", name: "memberships_role_valid"
    t.check_constraint "state IN ('active', 'suspended')", name: "memberships_state_valid"
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
    t.check_constraint "current_month_ticket_count >= 0", name: "organizations_current_month_ticket_count_non_negative"
    t.check_constraint "inbox_limit > 0", name: "organizations_inbox_limit_positive"
    t.check_constraint "next_ticket_sequence > 0", name: "organizations_next_ticket_sequence_positive"
    t.check_constraint "plan IN ('starter', 'growth', 'enterprise')", name: "organizations_plan_valid"
    t.check_constraint "seat_limit > 0", name: "organizations_seat_limit_positive"
    t.check_constraint "state IN ('active', 'suspended')", name: "organizations_state_valid"
    t.check_constraint "ticket_limit > 0", name: "organizations_ticket_limit_positive"
  end

  create_table "outbound_events", force: :cascade do |t|
    t.integer "aggregate_id", null: false
    t.string "aggregate_type", null: false
    t.integer "attempts_count", default: 0, null: false
    t.string "correlation_id", null: false
    t.datetime "created_at", null: false
    t.text "dead_letter_reason"
    t.datetime "dispatched_at"
    t.string "event_type", null: false
    t.datetime "failed_at"
    t.string "idempotency_key", null: false
    t.text "last_error"
    t.datetime "next_attempt_at"
    t.integer "organization_id", null: false
    t.json "payload", default: {}, null: false
    t.datetime "processing_started_at"
    t.string "relay_worker_id"
    t.integer "replayed_from_outbound_event_id"
    t.string "status", default: "pending", null: false
    t.datetime "updated_at", null: false
    t.index ["idempotency_key"], name: "index_outbound_events_on_idempotency_key", unique: true
    t.index ["organization_id", "status"], name: "index_outbound_events_on_organization_id_and_status"
    t.index ["organization_id"], name: "index_outbound_events_on_organization_id"
    t.index ["relay_worker_id"], name: "index_outbound_events_on_relay_worker_id"
    t.index ["replayed_from_outbound_event_id"], name: "index_outbound_events_on_replayed_from_outbound_event_id"
    t.index ["status", "failed_at"], name: "index_outbound_events_on_status_and_failed_at"
    t.index ["status", "next_attempt_at"], name: "index_outbound_events_on_status_and_next_attempt_at"
    t.check_constraint "attempts_count >= 0", name: "outbound_events_attempts_count_non_negative"
    t.check_constraint "dead_letter_reason IS NULL OR status = 'failed'", name: "outbound_events_dead_letter_reason_only_failed"
    t.check_constraint "failed_at IS NULL OR status = 'failed'", name: "outbound_events_failed_at_only_failed"
    t.check_constraint "next_attempt_at IS NULL OR status = 'pending'", name: "outbound_events_next_attempt_only_pending"
    t.check_constraint "status IN ('pending', 'processing', 'dispatched', 'failed')", name: "outbound_events_status_valid"
  end

  create_table "rate_limit_buckets", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.string "identifier_digest", null: false
    t.integer "requests_count", default: 0, null: false
    t.datetime "updated_at", null: false
    t.datetime "window_started_at", null: false
    t.index ["expires_at"], name: "index_rate_limit_buckets_on_expires_at"
    t.index ["identifier_digest", "window_started_at"], name: "idx_on_identifier_digest_window_started_at_a1775b6ae6", unique: true
    t.check_constraint "requests_count >= 0", name: "rate_limit_buckets_requests_count_non_negative"
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
    t.check_constraint "length(public_id) > 0", name: "tickets_public_id_present"
    t.check_constraint "lock_version >= 0", name: "tickets_lock_version_non_negative"
    t.check_constraint "priority IN ('low', 'normal', 'high', 'urgent')", name: "tickets_priority_valid"
    t.check_constraint "status IN ('open', 'pending', 'resolved', 'closed')", name: "tickets_status_valid"
  end

  add_foreign_key "audit_logs", "memberships"
  add_foreign_key "audit_logs", "organizations"
  add_foreign_key "memberships", "organizations"
  add_foreign_key "outbound_events", "organizations"
  add_foreign_key "outbound_events", "outbound_events", column: "replayed_from_outbound_event_id"
  add_foreign_key "tickets", "memberships", column: "assignee_membership_id"
  add_foreign_key "tickets", "memberships", column: "created_by_membership_id"
  add_foreign_key "tickets", "organizations"
end
