module Auditing
  class Logger
    def self.log!(organization:, membership:, auditable:, action:, metadata: {})
      AuditLog.create!(
        organization: organization,
        membership: membership,
        auditable: auditable,
        action: action,
        metadata: metadata,
        ip_address: Current.remote_ip,
        user_agent: Current.user_agent
      )
    end
  end
end
