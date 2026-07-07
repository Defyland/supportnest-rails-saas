require "digest"

module Experiments
  class Assign
    MIN_VARIANTS = 2

    def self.call!(...)
      new(...).call!
    end

    def initialize(organization:, experiment_key:, subject_key:, context: {})
      @organization = organization
      @experiment_key = normalize_experiment_key(experiment_key)
      @subject_key = normalize_subject_key(subject_key)
      @context = context.presence || {}
    end

    def call!
      validate_subject_key!
      assignment = nil

      ActiveRecord::Base.transaction do
        experiment.lock!
        ensure_assignable!
        assignment = existing_assignment || create_assignment!
      end

      assignment
    rescue ActiveRecord::RecordNotUnique
      experiment.experiment_assignments.find_by!(subject_key: subject_key)
    end

    private

    attr_reader :organization, :experiment_key, :subject_key, :context

    def experiment
      @experiment ||= organization.experiments.find_by!(key: experiment_key)
    end

    def existing_assignment
      experiment.experiment_assignments.includes(:experiment_variant).find_by(subject_key: subject_key)
    end

    def create_assignment!
      variant = choose_variant
      bucket_digest = digest_for(subject_key)

      experiment.experiment_assignments.create!(
        organization: organization,
        experiment_variant: variant,
        subject_key: subject_key,
        bucket_key_digest: bucket_digest,
        bucket_value: bucket_value(bucket_digest, total_weight),
        context: context
      )
    end

    def choose_variant
      selected_bucket = bucket_value(digest_for(subject_key), total_weight)
      variants.reduce(0) do |cumulative, variant|
        next_cumulative = cumulative + variant.weight
        return variant if selected_bucket < next_cumulative

        next_cumulative
      end
    end

    def ensure_assignable!
      raise ActiveRecord::RecordNotFound unless experiment.assignable?

      return if variants.size >= MIN_VARIANTS

      experiment.errors.add(:experiment_variants, "must include at least #{MIN_VARIANTS} active choices")
      raise ActiveRecord::RecordInvalid, experiment
    end

    def variants
      @variants ||= experiment.experiment_variants.order(:key).to_a
    end

    def total_weight
      @total_weight ||= variants.sum(&:weight)
    end

    def digest_for(value)
      Digest::SHA256.hexdigest("#{experiment.id}:#{value}")
    end

    def bucket_value(digest, modulo)
      digest[0, 16].to_i(16) % modulo
    end

    def validate_subject_key!
      return if subject_key.present? && subject_key.length <= 128

      experiment_assignment = ExperimentAssignment.new(subject_key: subject_key)
      experiment_assignment.valid?
      raise ActiveRecord::RecordInvalid, experiment_assignment
    end

    def normalize_experiment_key(value)
      value.to_s.strip.downcase
    end

    def normalize_subject_key(value)
      value.to_s.strip
    end
  end
end
