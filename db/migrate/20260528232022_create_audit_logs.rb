class CreateAuditLogs < ActiveRecord::Migration[8.1]
  def change
    create_table :audit_logs do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :membership, null: false, foreign_key: true
      t.string :action, null: false
      t.string :auditable_type, null: false
      t.integer :auditable_id, null: false
      t.json :metadata, null: false, default: {}
      t.string :ip_address
      t.string :user_agent

      t.timestamps
    end

    add_index :audit_logs, [ :organization_id, :created_at ]
    add_index :audit_logs, [ :auditable_type, :auditable_id ]
  end
end
