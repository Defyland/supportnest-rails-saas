module Memberships
  class RotateToken
    Result = Struct.new(:membership, :api_token, keyword_init: true)

    def self.call!(membership:, actor:)
      api_token, api_token_digest = Tokens::Issuer.issue(prefix: "sn_member_")

      ActiveRecord::Base.transaction do
        membership.organization.lock!
        membership.lock!
        OwnershipGuard.ensure_actor_can_manage_target!(membership: membership, actor: actor)

        membership.update!(
          api_token_digest: api_token_digest,
          api_token_last_eight: api_token.last(8),
          api_token_expires_at: Tokens::Issuer.expires_at,
          api_token_revoked_at: nil
        )

        Auditing::Logger.log!(
          organization: membership.organization,
          membership: actor,
          auditable: membership,
          action: "membership.token_rotated",
          metadata: { membership_id: membership.id, api_token_last_eight: membership.api_token_last_eight }
        )

        Events::Publisher.publish!(
          organization: membership.organization,
          aggregate: membership,
          event_type: "membership.token_rotated",
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
