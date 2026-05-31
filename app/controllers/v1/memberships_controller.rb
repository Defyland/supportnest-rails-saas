module V1
  class MembershipsController < ApplicationController
    def index
      authorize!(:memberships_list)

      memberships, pagination = paginate(current_organization.memberships.ordered)

      render json: {
        memberships: memberships.map do |membership|
          membership.as_api_json(include_private: true)
        end,
        pagination: pagination
      }
    end

    def create
      authorize!(:memberships_create)

      result = Memberships::Create.call!(
        organization: current_organization,
        actor: current_membership,
        attributes: membership_create_attributes
      )

      render json: {
        membership: result.membership.as_api_json(include_private: true).merge(api_token: result.api_token)
      }, status: :created
    end

    def update
      authorize!(:memberships_update)

      membership = current_organization.memberships.find(params[:id])
      Memberships::Update.call!(
        membership: membership,
        actor: current_membership,
        attributes: membership_update_attributes
      )

      render json: { membership: membership.as_api_json(include_private: true) }
    end

    def rotate_token
      authorize!(:memberships_rotate_token)

      membership = current_organization.memberships.find(params[:id])
      result = Memberships::RotateToken.call!(membership: membership, actor: current_membership)

      render json: {
        membership: result.membership.as_api_json(include_private: true).merge(api_token: result.api_token)
      }
    end

    def revoke_token
      authorize!(:memberships_revoke_token)

      membership = current_organization.memberships.find(params[:id])
      Memberships::RevokeToken.call!(membership: membership, actor: current_membership)

      render json: { membership: membership.as_api_json(include_private: true) }
    end

    private

    def membership_create_attributes
      payload = params.require(:membership)
      {
        email: payload[:email],
        full_name: payload[:full_name],
        role: payload[:role]
      }.compact
    end

    def membership_update_attributes
      payload = params.require(:membership)
      {
        full_name: payload[:full_name],
        role: payload[:role],
        state: payload[:state]
      }.compact
    end
  end
end
