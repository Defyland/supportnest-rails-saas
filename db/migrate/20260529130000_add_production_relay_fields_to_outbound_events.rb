class AddProductionRelayFieldsToOutboundEvents < ActiveRecord::Migration[8.1]
  def change
    add_column :outbound_events, :failed_at, :datetime
    add_column :outbound_events, :dead_letter_reason, :text
    add_column :outbound_events, :relay_worker_id, :string
    add_reference :outbound_events, :replayed_from_outbound_event, foreign_key: { to_table: :outbound_events }

    add_index :outbound_events, [ :status, :failed_at ]
    add_index :outbound_events, :relay_worker_id

    add_check_constraint :outbound_events, "failed_at IS NULL OR status = 'failed'",
                         name: "outbound_events_failed_at_only_failed"
    add_check_constraint :outbound_events, "dead_letter_reason IS NULL OR status = 'failed'",
                         name: "outbound_events_dead_letter_reason_only_failed"
  end
end
