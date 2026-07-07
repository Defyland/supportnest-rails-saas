module Experiments
  class Convert
    def self.call!(...)
      new(...).call!
    end

    def initialize(organization:, experiment_key:, subject_key:, event_name:, idempotency_key:, metadata: {})
      @organization = organization
      @experiment_key = experiment_key.to_s.strip.downcase
      @subject_key = subject_key.to_s.strip
      @event_name = event_name.to_s.strip.downcase
      @idempotency_key = idempotency_key.to_s.strip
      @metadata = metadata.presence || {}
    end

    def call!
      existing_conversion = organization.experiment_conversions.find_by(idempotency_key: idempotency_key)
      return existing_conversion if existing_conversion.present?

      ExperimentConversion.create!(
        organization: organization,
        experiment_assignment: assignment,
        event_name: event_name,
        idempotency_key: idempotency_key,
        metadata: metadata
      )
    rescue ActiveRecord::RecordNotUnique
      organization.experiment_conversions.find_by!(idempotency_key: idempotency_key)
    end

    private

    attr_reader :organization, :experiment_key, :subject_key, :event_name, :idempotency_key, :metadata

    def assignment
      @assignment ||= organization.experiment_assignments.joins(:experiment)
        .find_by!(subject_key: subject_key, experiments: { key: experiment_key })
    end
  end
end
