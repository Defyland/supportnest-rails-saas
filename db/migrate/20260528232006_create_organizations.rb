class CreateOrganizations < ActiveRecord::Migration[8.1]
  def change
    create_table :organizations do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.string :plan, null: false, default: "starter"
      t.string :state, null: false, default: "active"
      t.integer :seat_limit, null: false, default: 5
      t.integer :inbox_limit, null: false, default: 2
      t.integer :ticket_limit, null: false, default: 500
      t.integer :current_month_ticket_count, null: false, default: 0

      t.timestamps
    end

    add_index :organizations, :slug, unique: true
  end
end
