class AuditLog < ApplicationRecord
  belongs_to :organization
  belongs_to :membership
  belongs_to :auditable, polymorphic: true

  validates :action, presence: true
  validates :metadata, presence: true
end
