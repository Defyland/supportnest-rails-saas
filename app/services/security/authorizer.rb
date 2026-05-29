require "yaml"

module Security
  class Authorizer
    MATRIX_PATH = Rails.root.join("config/authorization_matrix.yml")
    PERMISSIONS = YAML.safe_load_file(MATRIX_PATH).fetch("roles").to_h do |role, permissions|
      [ role.to_sym, permissions.map(&:to_sym).freeze ]
    end.freeze

    def self.authorize!(membership, permission)
      allowed_permissions = PERMISSIONS.fetch(membership.role.to_sym)
      return if allowed_permissions.include?(permission)

      raise AuthorizationError, "#{membership.role} cannot perform #{permission}."
    end
  end
end
