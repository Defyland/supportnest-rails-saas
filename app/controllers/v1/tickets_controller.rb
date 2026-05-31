module V1
  class TicketsController < ApplicationController
    def index
      authorize!(:tickets_list)

      tickets = current_organization.tickets.includes(:created_by_membership, :assignee_membership).recent_first
      tickets = tickets.where(status: query_enum_param!(:status, Ticket.statuses.keys)) if params[:status].present?
      tickets = tickets.where(priority: query_enum_param!(:priority, Ticket.priorities.keys)) if params[:priority].present?
      inbox = query_inbox_param
      tickets = tickets.where(inbox: inbox) if inbox.present?
      tickets, pagination = paginate(tickets)

      render json: { tickets: tickets.map(&:as_api_json), pagination: pagination }
    end

    def create
      authorize!(:tickets_create)

      ticket = Tickets::Create.call!(
        organization: current_organization,
        actor: current_membership,
        attributes: ticket_params.to_h.symbolize_keys
      )

      set_ticket_etag(ticket)
      render json: { ticket: ticket.as_api_json }, status: :created
    end

    def show
      authorize!(:tickets_read)

      ticket = current_organization.tickets.includes(:created_by_membership, :assignee_membership)
                                   .find_by!(public_id: params[:id])

      set_ticket_etag(ticket)
      render json: { ticket: ticket.as_api_json }
    end

    def update
      authorize!(:tickets_update)

      ticket = current_organization.tickets.includes(:created_by_membership, :assignee_membership)
                                   .find_by!(public_id: params[:id])
      expected_lock_version = required_if_match_lock_version
      return if performed?

      unless ticket.lock_version == expected_lock_version
        return render_error(
          code: "conflict",
          message: "Ticket version is stale.",
          status: :conflict,
          details: {
            expected_lock_version: expected_lock_version,
            current_lock_version: ticket.lock_version
          }
        )
      end

      Tickets::Update.call!(
        ticket: ticket,
        actor: current_membership,
        attributes: ticket_update_params.to_h.symbolize_keys
      )

      ticket.reload
      set_ticket_etag(ticket)
      render json: { ticket: ticket.as_api_json }
    end

    private

    def ticket_params
      params.require(:ticket).permit(
        :subject,
        :description,
        :requester_name,
        :requester_email,
        :inbox,
        :priority,
        :assignee_membership_id
      )
    end

    def ticket_update_params
      params.require(:ticket).permit(:status, :priority, :inbox, :assignee_membership_id)
    end

    def required_if_match_lock_version
      raw_value = request.headers["If-Match"].to_s.strip

      if raw_value.blank?
        render_error(
          code: "precondition_required",
          message: "If-Match header is required for ticket updates.",
          status: :precondition_required
        )
        return
      end

      normalized_value = raw_value.delete_prefix('"').delete_suffix('"')
      Integer(normalized_value, 10)
    rescue ArgumentError
      render_error(
        code: "precondition_failed",
        message: "If-Match must contain the current ticket lock version.",
        status: :precondition_failed
      )
      nil
    end

    def set_ticket_etag(ticket)
      response.set_header("ETag", %("#{ticket.lock_version}"))
    end

    def query_inbox_param
      raw_value = params[:inbox]
      return if raw_value.blank?

      inbox = Ticket.normalize_inbox(raw_value)
      return inbox if inbox.present? && Ticket::INBOX_FORMAT.match?(inbox)

      raise InvalidParameter.new(
        "inbox must be a URL-safe key.",
        details: { inbox: [ "must be a URL-safe key" ] }
      )
    end
  end
end
