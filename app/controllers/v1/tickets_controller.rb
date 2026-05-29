module V1
  class TicketsController < ApplicationController
    def index
      authorize!(:tickets_list)

      tickets = current_organization.tickets.includes(:created_by_membership, :assignee_membership).recent_first
      tickets = tickets.where(status: params[:status]) if params[:status].present?
      tickets = tickets.where(priority: params[:priority]) if params[:priority].present?
      tickets = tickets.where(inbox: params[:inbox]) if params[:inbox].present?

      render json: { tickets: tickets.map(&:as_api_json) }
    end

    def create
      authorize!(:tickets_create)

      ticket = Tickets::Create.call!(
        organization: current_organization,
        actor: current_membership,
        attributes: ticket_params.to_h.symbolize_keys
      )

      render json: { ticket: ticket.as_api_json }, status: :created
    end

    def show
      authorize!(:tickets_read)

      ticket = current_organization.tickets.includes(:created_by_membership, :assignee_membership)
                                   .find_by!(public_id: params[:id])

      render json: { ticket: ticket.as_api_json }
    end

    def update
      authorize!(:tickets_update)

      ticket = current_organization.tickets.includes(:created_by_membership, :assignee_membership)
                                   .find_by!(public_id: params[:id])

      Tickets::Update.call!(
        ticket: ticket,
        actor: current_membership,
        attributes: ticket_update_params.to_h.symbolize_keys
      )

      render json: { ticket: ticket.reload.as_api_json }
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
  end
end
