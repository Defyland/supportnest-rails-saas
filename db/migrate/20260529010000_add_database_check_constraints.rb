class AddDatabaseCheckConstraints < ActiveRecord::Migration[8.1]
  def change
    add_check_constraint :organizations, "seat_limit > 0", name: "organizations_seat_limit_positive"
    add_check_constraint :organizations, "inbox_limit > 0", name: "organizations_inbox_limit_positive"
    add_check_constraint :organizations, "ticket_limit > 0", name: "organizations_ticket_limit_positive"
    add_check_constraint :organizations, "current_month_ticket_count >= 0",
                         name: "organizations_current_month_ticket_count_non_negative"
    add_check_constraint :organizations, "next_ticket_sequence > 0", name: "organizations_next_ticket_sequence_positive"
    add_check_constraint :organizations, "plan IN ('starter', 'growth', 'enterprise')",
                         name: "organizations_plan_valid"
    add_check_constraint :organizations, "state IN ('active', 'suspended')", name: "organizations_state_valid"

    add_check_constraint :memberships, "role IN ('owner', 'admin', 'agent', 'viewer')", name: "memberships_role_valid"
    add_check_constraint :memberships, "state IN ('active', 'suspended')", name: "memberships_state_valid"
    add_check_constraint :memberships, "length(api_token_last_eight) = 8", name: "memberships_token_last_eight_length"

    add_check_constraint :tickets, "status IN ('open', 'pending', 'resolved', 'closed')", name: "tickets_status_valid"
    add_check_constraint :tickets, "priority IN ('low', 'normal', 'high', 'urgent')", name: "tickets_priority_valid"
    add_check_constraint :tickets, "lock_version >= 0", name: "tickets_lock_version_non_negative"
    add_check_constraint :tickets, "length(public_id) > 0", name: "tickets_public_id_present"

    add_check_constraint :outbound_events, "status IN ('pending', 'dispatched', 'failed')",
                         name: "outbound_events_status_valid"
    add_check_constraint :outbound_events, "attempts_count >= 0", name: "outbound_events_attempts_count_non_negative"
  end
end
