module Tickets
  class InboxLimit
    def self.ensure_available!(organization:, inbox:, excluding_ticket: nil)
      normalized_inbox = Ticket.normalize_inbox(inbox)
      return if normalized_inbox.blank?

      tickets = organization.tickets
      tickets = tickets.where.not(id: excluding_ticket.id) if excluding_ticket&.persisted?

      return if tickets.where(inbox: normalized_inbox).exists?
      return if tickets.distinct.count(:inbox) < organization.inbox_limit

      organization.errors.add(:inbox_limit, "has been reached for the current plan")
      raise ActiveRecord::RecordInvalid, organization
    end
  end
end
