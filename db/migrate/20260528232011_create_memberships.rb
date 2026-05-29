class CreateMemberships < ActiveRecord::Migration[8.1]
  def change
    create_table :memberships do |t|
      t.references :organization, null: false, foreign_key: true
      t.string :email, null: false
      t.string :full_name, null: false
      t.string :role, null: false, default: "agent"
      t.string :state, null: false, default: "active"
      t.string :api_token_digest, null: false
      t.string :api_token_last_eight, null: false
      t.datetime :last_seen_at

      t.timestamps
    end

    add_index :memberships, [ :organization_id, :email ], unique: true
    add_index :memberships, :api_token_digest, unique: true
    add_index :memberships, [ :organization_id, :role ]
  end
end
