class AddRetryStateToOutboundEvents < ActiveRecord::Migration[8.1]
  def change
    add_column :outbound_events, :next_attempt_at, :datetime
    add_column :outbound_events, :processing_started_at, :datetime
    add_index :outbound_events, [ :status, :next_attempt_at ]

    remove_check_constraint :outbound_events, name: "outbound_events_status_valid"
    add_check_constraint :outbound_events, "status IN ('pending', 'processing', 'dispatched', 'failed')",
                         name: "outbound_events_status_valid"
    add_check_constraint :outbound_events, "next_attempt_at IS NULL OR status = 'pending'",
                         name: "outbound_events_next_attempt_only_pending"
  end
end
