module Memberships
  class Create
    Result = Struct.new(:membership, :api_token, keyword_init: true)

    def self.call!(organization:, actor:, attributes:)
      role = attributes.fetch(:role, "agent")
      raise Security::AuthorizationError, "The owner role can only be created during bootstrap." if role == "owner"

      api_token, api_token_digest = Tokens::Issuer.issue(prefix: "sn_member_")
      membership = nil

      ActiveRecord::Base.transaction do
        organization.lock!

        unless organization.seat_available?
          organization.errors.add(:seat_limit, "has been reached for the current plan")
          raise ActiveRecord::RecordInvalid, organization
        end

        membership = organization.memberships.create!(
          attributes.merge(
            role: role,
            state: "active",
            api_token_digest: api_token_digest,
            api_token_last_eight: api_token.last(8)
          )
        )

        Auditing::Logger.log!(
          organization: organization,
          membership: actor,
          auditable: membership,
          action: "membership.created",
          metadata: { membership_id: membership.id, role: membership.role }
        )

        Events::Publisher.publish!(
          organization: organization,
          aggregate: membership,
          event_type: "membership.created",
          payload: {
            membership: membership.as_api_json(include_private: true),
            actor_membership_id: actor.id
          }
        )
      end

      Result.new(membership: membership, api_token: api_token)
    end
  end
end
