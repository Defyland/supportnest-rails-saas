module Tickets
  class Create
    def self.call!(organization:, actor:, attributes:)
      ticket = nil

      ActiveRecord::Base.transaction do
        organization.lock!

        unless organization.ticket_quota_available?
          organization.errors.add(:ticket_limit, "has been reached for the current month")
          raise ActiveRecord::RecordInvalid, organization
        end

        public_id = format("TCK-%06d", organization.next_ticket_sequence)

        ticket = organization.tickets.create!(
          attributes.merge(
            created_by_membership: actor,
            public_id: public_id
          )
        )

        organization.update!(
          current_month_ticket_count: organization.current_month_ticket_count + 1,
          next_ticket_sequence: organization.next_ticket_sequence + 1
        )

        Auditing::Logger.log!(
          organization: organization,
          membership: actor,
          auditable: ticket,
          action: "ticket.created",
          metadata: { ticket_id: ticket.public_id, priority: ticket.priority }
        )

        Events::Publisher.publish!(
          organization: organization,
          aggregate: ticket,
          event_type: "ticket.created",
          payload: {
            ticket: ticket.as_api_json,
            actor_membership_id: actor.id
          }
        )
      end

      ticket
    end
  end
end
