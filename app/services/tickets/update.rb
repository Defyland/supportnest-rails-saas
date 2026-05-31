module Tickets
  class Update
    def self.call!(ticket:, actor:, attributes:)
      ActiveRecord::Base.transaction do
        ticket.organization.lock!
        ticket.assign_attributes(attributes)
        apply_status_timestamps(ticket)
        raise ActiveRecord::RecordInvalid, ticket unless ticket.valid?

        if ticket.changed?
          InboxLimit.ensure_available!(
            organization: ticket.organization,
            inbox: ticket.inbox,
            excluding_ticket: ticket
          ) if ticket.will_save_change_to_inbox?

          ticket.save!
          changes = ticket.saved_changes.except("updated_at")

          Auditing::Logger.log!(
            organization: ticket.organization,
            membership: actor,
            auditable: ticket,
            action: "ticket.updated",
            metadata: { changes: changes }
          )

          Events::Publisher.publish!(
            organization: ticket.organization,
            aggregate: ticket,
            event_type: "ticket.updated",
            payload: {
              ticket: ticket.as_api_json,
              actor_membership_id: actor.id,
              changes: changes
            }
          )
        end
      end

      ticket
    end

    def self.apply_status_timestamps(ticket)
      return unless ticket.will_save_change_to_status?

      ticket.first_response_at ||= Time.current if ticket.status != "open"
      ticket.closed_at = %w[resolved closed].include?(ticket.status) ? Time.current : nil
    end
  end
end
