class Organization < ApplicationRecord
  has_many :memberships, dependent: :destroy
  has_many :tickets, dependent: :destroy
  has_many :audit_logs, dependent: :destroy
  has_many :outbound_events, dependent: :destroy
  has_many :experiments, dependent: :destroy
  has_many :experiment_assignments, dependent: :destroy
  has_many :experiment_conversions, dependent: :destroy

  enum :plan, {
    starter: "starter",
    growth: "growth",
    enterprise: "enterprise"
  }, validate: true

  enum :state, {
    active: "active",
    suspended: "suspended"
  }, validate: true

  before_validation :normalize_slug

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true,
                   format: { with: /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/ }
  validates :seat_limit, numericality: { greater_than: 0 }
  validates :inbox_limit, numericality: { greater_than: 0 }
  validates :ticket_limit, numericality: { greater_than: 0 }
  validates :current_month_ticket_count, numericality: { greater_than_or_equal_to: 0 }
  validates :next_ticket_sequence, numericality: { greater_than: 0 }

  def seat_available?
    memberships.active.count < seat_limit
  end

  def ticket_quota_available?
    current_month_ticket_count < ticket_limit
  end

  def as_api_json
    {
      id: id,
      name: name,
      slug: slug,
      plan: plan,
      state: state,
      seat_limit: seat_limit,
      inbox_limit: inbox_limit,
      ticket_limit: ticket_limit,
      current_month_ticket_count: current_month_ticket_count,
      next_ticket_sequence: next_ticket_sequence,
      created_at: created_at&.iso8601,
      updated_at: updated_at&.iso8601
    }
  end

  private

  def normalize_slug
    self.slug = slug.to_s.parameterize if slug.present?
  end
end
