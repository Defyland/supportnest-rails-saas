module V1
  class OrganizationsController < ApplicationController
    skip_before_action :authenticate_membership!, only: :create

    def create
      result = Organizations::Bootstrap.call!(
        organization_attributes: organization_params.to_h.symbolize_keys,
        owner_attributes: owner_params.to_h.symbolize_keys
      )

      render json: {
        organization: result.organization.as_api_json,
        owner: result.owner_membership.as_api_json(include_private: true).merge(api_token: result.api_token)
      }, status: :created
    end

    def show
      authorize!(:organizations_read)

      render json: {
        organization: current_organization.as_api_json,
        actor: current_membership.as_api_json(include_private: true)
      }
    end

    private

    def organization_params
      params.require(:organization).permit(
        :name,
        :slug,
        :plan,
        :seat_limit,
        :inbox_limit,
        :ticket_limit
      )
    end

    def owner_params
      params.require(:owner).permit(:email, :full_name)
    end
  end
end
