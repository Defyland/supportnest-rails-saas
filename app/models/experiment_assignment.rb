class ExperimentAssignment < ApplicationRecord
  belongs_to :organization
  belongs_to :experiment
  belongs_to :experiment_variant
  has_many :experiment_conversions, dependent: :destroy

  before_validation :assign_assigned_at, on: :create

  validates :subject_key, presence: true, length: { maximum: 128 }
  validates :bucket_key_digest, presence: true, length: { is: 64 }
  validates :bucket_value, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :context_must_be_json_object

  validate :experiment_belongs_to_organization
  validate :variant_belongs_to_experiment

  def as_api_json
    {
      experiment_key: experiment.key,
      subject_key: subject_key,
      variant: experiment_variant.as_api_json,
      bucket_value: bucket_value,
      assigned_at: assigned_at&.iso8601
    }
  end

  private

  def assign_assigned_at
    self.assigned_at ||= Time.current
  end

  def experiment_belongs_to_organization
    return if organization.blank? || experiment.blank?

    errors.add(:experiment, "must belong to the same organization") if experiment.organization_id != organization_id
  end

  def variant_belongs_to_experiment
    return if experiment.blank? || experiment_variant.blank?

    errors.add(:experiment_variant, "must belong to the experiment") if experiment_variant.experiment_id != experiment_id
  end

  def context_must_be_json_object
    errors.add(:context, "must be a JSON object") unless context.is_a?(Hash)
  end
end
