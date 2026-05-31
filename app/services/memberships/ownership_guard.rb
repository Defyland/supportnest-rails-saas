module Memberships
  module OwnershipGuard
    module_function

    def ensure_actor_can_manage_target!(membership:, actor:)
      return unless membership.owner?
      return if actor.owner?

      raise Security::AuthorizationError, "Only owners may manage owner memberships."
    end

    def ensure_update_preserves_owner_access!(membership:, attributes:)
      return unless removes_authenticatable_owner_access?(membership, attributes)
      return if other_authenticatable_owner_exists?(membership)

      raise Security::AuthorizationError, "Organizations must keep at least one active owner with a valid token."
    end

    def ensure_token_revocation_preserves_owner_access!(membership:)
      return unless authenticatable_owner?(membership)
      return if other_authenticatable_owner_exists?(membership)

      raise Security::AuthorizationError, "Organizations must keep at least one active owner with a valid token."
    end

    def authenticatable_owner?(membership)
      membership.owner? && membership.active? && !membership.api_token_revoked? && !membership.api_token_expired?
    end

    def other_authenticatable_owner_exists?(membership)
      membership.organization.memberships
                .where(role: "owner", state: "active", api_token_revoked_at: nil)
                .where("api_token_expires_at > ?", Time.current)
                .where.not(id: membership.id)
                .exists?
    end

    def removes_authenticatable_owner_access?(membership, attributes)
      return false unless authenticatable_owner?(membership)

      normalized_attributes = attributes.to_h.transform_keys(&:to_sym)
      next_role = normalized_attributes.fetch(:role, membership.role).to_s
      next_state = normalized_attributes.fetch(:state, membership.state).to_s

      next_role != "owner" || next_state != "active"
    end
  end
end
