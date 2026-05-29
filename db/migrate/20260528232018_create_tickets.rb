class CreateTickets < ActiveRecord::Migration[8.1]
  def change
    create_table :tickets do |t|
      t.references :organization, null: false, foreign_key: true
      t.string :public_id, null: false
      t.string :subject, null: false
      t.text :description, null: false
      t.string :requester_name, null: false
      t.string :requester_email, null: false
      t.string :inbox, null: false, default: "general"
      t.string :status, null: false, default: "open"
      t.string :priority, null: false, default: "normal"
      t.references :created_by_membership, null: false, foreign_key: { to_table: :memberships }
      t.references :assignee_membership, foreign_key: { to_table: :memberships }
      t.datetime :closed_at
      t.datetime :first_response_at
      t.datetime :resolution_due_at
      t.integer :lock_version, null: false, default: 0

      t.timestamps
    end

    add_index :tickets, [ :organization_id, :public_id ], unique: true
    add_index :tickets, [ :organization_id, :status ]
    add_index :tickets, [ :organization_id, :requester_email ]
  end
end
