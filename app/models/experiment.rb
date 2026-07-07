class Experiment < ApplicationRecord
  KEY_FORMAT = /\A[a-z0-9]+(?:[._-][a-z0-9]+)*\z/

  belongs_to :organization
  has_many :experiment_variants, dependent: :destroy
  has_many :experiment_assignments, dependent: :destroy

  enum :status, {
    draft: "draft",
    active: "active",
    paused: "paused",
    archived: "archived"
  }, validate: true

  before_validation :normalize_key

  validates :key, presence: true, length: { maximum: 80 }, format: { with: KEY_FORMAT },
                  uniqueness: { scope: :organization_id }
  validates :name, presence: true, length: { maximum: 120 }

  def assignable?
    active?
  end

  def as_api_json
    {
      key: key,
      name: name,
      status: status,
      variants: experiment_variants.order(:key).map(&:as_api_json),
      created_at: created_at&.iso8601,
      updated_at: updated_at&.iso8601
    }
  end

  private

  def normalize_key
    self.key = key.to_s.strip.downcase if key.present?
  end
end
