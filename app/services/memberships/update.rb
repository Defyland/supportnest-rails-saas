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
        membership.organization.lock!
        membership.lock!
        OwnershipGuard.ensure_actor_can_manage_target!(membership: membership, actor: actor)
        OwnershipGuard.ensure_update_preserves_owner_access!(membership: membership, attributes: attributes)
        ensure_seat_available_for_activation!(membership, attributes)

        membership.assign_attributes(attributes)
        if membership.changed?
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
      end

      membership
    end

    def self.ensure_seat_available_for_activation!(membership, attributes)
      normalized_attributes = attributes.to_h.transform_keys(&:to_sym)
      next_state = normalized_attributes.fetch(:state, membership.state).to_s
      return unless next_state == "active"
      return if membership.active?
      return if membership.organization.seat_available?

      membership.organization.errors.add(:seat_limit, "has been reached for the current plan")
      raise ActiveRecord::RecordInvalid, membership.organization
    end
  end
end
