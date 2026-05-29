class Current < ActiveSupport::CurrentAttributes
  attribute :request_id, :correlation_id, :membership, :organization, :remote_ip, :user_agent
end
