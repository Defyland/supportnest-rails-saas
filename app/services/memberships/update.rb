module Memberships
  class Update
    def self.call!(membership:, actor:, attributes:)
      if membership == actor && attributes[:state] == "suspended"
        raise Security::AuthorizationError, "Members cannot suspend themselves."
      end

      if attributes[:role] == "owner" && actor.role != "owner"
        raise Security::AuthorizationError, "Only owners may assign the owner role."
      end

      ActiveRecord::Base.transaction do
        membership.assign_attributes(attributes)
        membership.save!
        changes = membership.saved_changes.except("updated_at")

        Auditing::Logger.log!(
          organization: membership.organization,
          membership: actor,
          auditable: membership,
          action: "membership.updated",
          metadata: { changes: changes }
        )

        Events::Publisher.publish!(
          organization: membership.organization,
          aggregate: membership,
          event_type: "membership.updated",
          payload: {
            membership: membership.as_api_json(include_private: true),
            actor_membership_id: actor.id,
            changes: changes
          }
        )
      end

      membership
    end
  end
end
