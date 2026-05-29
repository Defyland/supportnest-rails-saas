module Security
  class Authorizer
    PERMISSIONS = {
      owner: %i[
        organizations_read
        memberships_list
        memberships_create
        memberships_update
        tickets_list
        tickets_read
        tickets_create
        tickets_update
      ],
      admin: %i[
        organizations_read
        memberships_list
        memberships_create
        memberships_update
        tickets_list
        tickets_read
        tickets_create
        tickets_update
      ],
      agent: %i[
        organizations_read
        memberships_list
        tickets_list
        tickets_read
        tickets_create
        tickets_update
      ],
      viewer: %i[
        organizations_read
        memberships_list
        tickets_list
        tickets_read
      ]
    }.freeze

    def self.authorize!(membership, permission)
      allowed_permissions = PERMISSIONS.fetch(membership.role.to_sym)
      return if allowed_permissions.include?(permission)

      raise AuthorizationError, "#{membership.role} cannot perform #{permission}."
    end
  end
end
