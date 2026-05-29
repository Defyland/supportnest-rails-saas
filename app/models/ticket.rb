class Ticket < ApplicationRecord
  belongs_to :organization
  belongs_to :created_by_membership, class_name: "Membership", inverse_of: :created_tickets
  belongs_to :assignee_membership, class_name: "Membership", inverse_of: :assigned_tickets, optional: true
  has_many :audit_logs, as: :auditable, dependent: :destroy

  enum :status, {
    open: "open",
    pending: "pending",
    resolved: "resolved",
    closed: "closed"
  }, validate: true

  enum :priority, {
    low: "low",
    normal: "normal",
    high: "high",
    urgent: "urgent"
  }, validate: true

  before_validation :normalize_requester_email
  before_validation :assign_resolution_due_at, on: :create

  validates :subject, presence: true, length: { maximum: 140 }
  validates :description, presence: true
  validates :requester_name, presence: true
  validates :requester_email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :public_id, presence: true, uniqueness: { scope: :organization_id }
  validates :inbox, presence: true

  validate :memberships_belong_to_organization

  scope :recent_first, -> { order(created_at: :desc) }

  def as_api_json
    {
      id: public_id,
      subject: subject,
      description: description,
      requester_name: requester_name,
      requester_email: requester_email,
      inbox: inbox,
      status: status,
      priority: priority,
      lock_version: lock_version,
      first_response_at: first_response_at&.iso8601,
      resolution_due_at: resolution_due_at&.iso8601,
      closed_at: closed_at&.iso8601,
      created_at: created_at&.iso8601,
      updated_at: updated_at&.iso8601,
      created_by: created_by_membership.as_api_json,
      assignee: assignee_membership&.as_api_json
    }
  end

  private

  def normalize_requester_email
    self.requester_email = requester_email.to_s.strip.downcase if requester_email.present?
  end

  def assign_resolution_due_at
    return if resolution_due_at.present?

    self.resolution_due_at =
      case priority
      when "urgent" then 4.hours.from_now
      when "high" then 8.hours.from_now
      else 24.hours.from_now
      end
  end

  def memberships_belong_to_organization
    return if organization.blank?

    if created_by_membership&.organization_id != organization_id
      errors.add(:created_by_membership, "must belong to the same organization")
    end

    if assignee_membership.present? && assignee_membership.organization_id != organization_id
      errors.add(:assignee_membership, "must belong to the same organization")
    end
  end
end
