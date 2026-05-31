class AddTicketInboxConstraints < ActiveRecord::Migration[8.1]
  def change
    add_index :tickets, [ :organization_id, :inbox ], name: "index_tickets_on_organization_id_and_inbox"
    add_check_constraint :tickets, "length(inbox) > 0 AND length(inbox) <= 64", name: "tickets_inbox_length"
  end
end
