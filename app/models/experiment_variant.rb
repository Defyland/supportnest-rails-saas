class ExperimentVariant < ApplicationRecord
  belongs_to :experiment
  has_many :experiment_assignments, dependent: :restrict_with_exception

  before_validation :normalize_key

  validates :key, presence: true, length: { maximum: 80 }, format: { with: Experiment::KEY_FORMAT },
                  uniqueness: { scope: :experiment_id }
  validates :name, presence: true, length: { maximum: 120 }
  validates :weight, numericality: { only_integer: true, greater_than: 0 }

  def as_api_json
    {
      key: key,
      name: name,
      weight: weight
    }
  end

  private

  def normalize_key
    self.key = key.to_s.strip.downcase if key.present?
  end
end
