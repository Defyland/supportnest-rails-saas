module Organizations
  class Bootstrap
    Result = Struct.new(:organization, :owner_membership, :api_token, keyword_init: true)

    def self.call!(organization_attributes:, owner_attributes:)
      organization = Organization.new(organization_attributes)
      api_token, api_token_digest = Tokens::Issuer.issue(prefix: "sn_owner_")
      owner_membership = nil

      ActiveRecord::Base.transaction do
        organization.save!
        owner_membership = organization.memberships.create!(
          owner_attributes.merge(
            role: "owner",
            state: "active",
            api_token_digest: api_token_digest,
            api_token_last_eight: api_token.last(8),
            api_token_expires_at: Tokens::Issuer.expires_at
          )
        )

        Auditing::Logger.log!(
          organization: organization,
          membership: owner_membership,
          auditable: organization,
          action: "organization.bootstrapped",
          metadata: { plan: organization.plan, owner_email: owner_membership.email }
        )

        Events::Publisher.publish!(
          organization: organization,
          aggregate: organization,
          event_type: "organization.bootstrapped",
          payload: {
            organization: organization.as_api_json,
            owner_membership_id: owner_membership.id
          }
        )
      end

      Result.new(
        organization: organization,
        owner_membership: owner_membership,
        api_token: api_token
      )
    end
  end
end
