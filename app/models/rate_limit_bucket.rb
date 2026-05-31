class RateLimitBucket < ApplicationRecord
  validates :identifier_digest, :window_started_at, :expires_at, presence: true
  validates :requests_count, numericality: { greater_than_or_equal_to: 0 }

  scope :expired, ->(now = Time.current) { where("expires_at <= ?", now) }
end
