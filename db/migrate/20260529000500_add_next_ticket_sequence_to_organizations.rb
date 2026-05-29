class AddNextTicketSequenceToOrganizations < ActiveRecord::Migration[8.1]
  def change
    add_column :organizations, :next_ticket_sequence, :integer, null: false, default: 1
  end
end
