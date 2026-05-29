class Membership < ApplicationRecord
  belongs_to :organization
  has_many :created_tickets, class_name: "Ticket", foreign_key: :created_by_membership_id,
                             inverse_of: :created_by_membership
  has_many :assigned_tickets, class_name: "Ticket", foreign_key: :assignee_membership_id,
                              inverse_of: :assignee_membership
  has_many :audit_logs

  enum :role, {
    owner: "owner",
    admin: "admin",
    agent: "agent",
    viewer: "viewer"
  }, validate: true

  enum :state, {
    active: "active",
    suspended: "suspended"
  }, validate: true

  before_validation :normalize_email

  validates :email, presence: true,
                    format: { with: URI::MailTo::EMAIL_REGEXP },
                    uniqueness: { scope: :organization_id }
  validates :full_name, presence: true
  validates :api_token_digest, presence: true, uniqueness: true
  validates :api_token_last_eight, presence: true

  scope :ordered, -> { order(:email) }

  def self.authenticate(raw_token)
    return if raw_token.blank?

    find_by(api_token_digest: Security::TokenAuthenticator.digest(raw_token), state: "active")
  end

  def touch_last_seen!
    update_column(:last_seen_at, Time.current)
  end

  def as_api_json(include_private: false)
    {
      id: id,
      email: email,
      full_name: full_name,
      role: role,
      state: state,
      api_token_last_eight: include_private ? api_token_last_eight : nil,
      last_seen_at: last_seen_at&.iso8601,
      created_at: created_at&.iso8601,
      updated_at: updated_at&.iso8601
    }.compact
  end

  private

  def normalize_email
    self.email = email.to_s.strip.downcase if email.present?
  end
end
