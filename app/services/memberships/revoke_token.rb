module Memberships
  class RevokeToken
    def self.call!(membership:, actor:)
      ActiveRecord::Base.transaction do
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
