module Memberships
  class RevokeToken
    def self.call!(membership:, actor:)
      ActiveRecord::Base.transaction do
        membership.organization.lock!
        membership.lock!
        OwnershipGuard.ensure_actor_can_manage_target!(membership: membership, actor: actor)
        OwnershipGuard.ensure_token_revocation_preserves_owner_access!(membership: membership)

        membership.update!(api_token_revoked_at: Time.current)

        Auditing::Logger.log!(
          organization: membership.organization,
          membership: actor,
          auditable: membership,
          action: "membership.token_revoked",
          metadata: { membership_id: membership.id }
        )

        Events::Publisher.publish!(
          organization: membership.organization,
          aggregate: membership,
          event_type: "membership.token_revoked",
          payload: {
            membership: membership.as_api_json(include_private: true),
            actor_membership_id: actor.id
          }
        )
      end

      membership
    end
  end
end
