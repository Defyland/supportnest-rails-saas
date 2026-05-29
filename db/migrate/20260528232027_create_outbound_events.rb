class CreateOutboundEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :outbound_events do |t|
      t.references :organization, null: false, foreign_key: true
      t.string :aggregate_type, null: false
      t.integer :aggregate_id, null: false
      t.string :event_type, null: false
      t.string :status, null: false, default: "pending"
      t.json :payload, null: false, default: {}
      t.string :idempotency_key, null: false
      t.string :correlation_id, null: false
      t.integer :attempts_count, null: false, default: 0
      t.text :last_error
      t.datetime :dispatched_at

      t.timestamps
    end

    add_index :outbound_events, :idempotency_key, unique: true
    add_index :outbound_events, [ :organization_id, :status ]
  end
end
