class ExperimentConversion < ApplicationRecord
  belongs_to :organization
  belongs_to :experiment_assignment

  before_validation :assign_occurred_at, on: :create

  validates :event_name, presence: true, length: { maximum: 80 }, format: { with: Experiment::KEY_FORMAT }
  validates :idempotency_key, presence: true, length: { maximum: 160 }, uniqueness: { scope: :organization_id }
  validate :metadata_must_be_json_object

  validate :assignment_belongs_to_organization

  def as_api_json
    {
      experiment_key: experiment_assignment.experiment.key,
      subject_key: experiment_assignment.subject_key,
      variant_key: experiment_assignment.experiment_variant.key,
      event_name: event_name,
      idempotency_key: idempotency_key,
      occurred_at: occurred_at&.iso8601
    }
  end

  private

  def assign_occurred_at
    self.occurred_at ||= Time.current
  end

  def assignment_belongs_to_organization
    return if organization.blank? || experiment_assignment.blank?

    if experiment_assignment.organization_id != organization_id
      errors.add(:experiment_assignment, "must belong to the same organization")
    end
  end

  def metadata_must_be_json_object
    errors.add(:metadata, "must be a JSON object") unless metadata.is_a?(Hash)
  end
end
