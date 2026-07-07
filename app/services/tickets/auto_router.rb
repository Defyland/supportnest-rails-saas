module Tickets
  class AutoRouter
    EXPERIMENT_KEY = "ticket-auto-routing"
    DEFAULT_POLICY = "least-open-tickets"
    SUPPORTED_POLICIES = %w[least-open-tickets sla-priority].freeze
    OPEN_WORK_STATUSES = %w[open pending].freeze
    ELIGIBLE_ROLES = %w[admin agent].freeze
    PRIORITY_WEIGHTS = {
      "urgent" => 8,
      "high" => 4,
      "normal" => 2,
      "low" => 1
    }.freeze

    Decision = Data.define(:policy_key, :assignee, :scores, :experiment_assignment, :reason) do
      def assigned?
        assignee.present?
      end

      def as_json
        {
          policy_key: policy_key,
          assignee_membership_id: assignee&.id,
          reason: reason,
          experiment_variant_key: experiment_assignment&.experiment_variant&.key,
          scores: scores
        }.compact
      end
    end

    def self.call!(...)
      new(...).call!
    end

    def initialize(organization:, ticket_attributes:)
      @organization = organization
      @ticket_attributes = ticket_attributes
    end

    def call!
      return no_candidate_decision if candidates.empty?

      policy_key, assignment = experiment_policy
      assignee = best_candidate(policy_key)

      Decision.new(
        policy_key: policy_key,
        assignee: assignee,
        scores: scorecard(policy_key),
        experiment_assignment: assignment,
        reason: assignment.present? ? "experiment_variant" : "default_policy"
      )
    end

    private

    attr_reader :organization, :ticket_attributes

    def candidates
      @candidates ||= organization.memberships.active.where(role: ELIGIBLE_ROLES).order(:id).to_a
    end

    def experiment_policy
      assignment = assign_experiment
      policy_key = assignment&.experiment_variant&.key

      return [ policy_key, assignment ] if SUPPORTED_POLICIES.include?(policy_key)

      [ DEFAULT_POLICY, assignment ]
    end

    def assign_experiment
      return unless organization.experiments.exists?(key: EXPERIMENT_KEY, status: "active")

      Experiments::Assign.call!(
        organization: organization,
        experiment_key: EXPERIMENT_KEY,
        subject_key: subject_key,
        context: {
          "inbox" => ticket_attributes[:inbox].presence || Ticket.column_defaults.fetch("inbox"),
          "priority" => ticket_attributes[:priority].presence || Ticket.column_defaults.fetch("priority")
        }
      )
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotFound
      nil
    end

    def subject_key
      ticket_attributes[:requester_email].to_s.strip.downcase
    end

    def best_candidate(policy_key)
      candidates.min_by do |candidate|
        candidate_score(candidate, policy_key)
      end
    end

    def candidate_score(candidate, policy_key)
      case policy_key
      when "sla-priority"
        [ weighted_loads.fetch(candidate.id, 0), open_counts.fetch(candidate.id, 0), candidate.id ]
      else
        [ open_counts.fetch(candidate.id, 0), weighted_loads.fetch(candidate.id, 0), candidate.id ]
      end
    end

    def scorecard(policy_key)
      candidates.index_with do |candidate|
        {
          policy_score: candidate_score(candidate, policy_key).first,
          open_ticket_count: open_counts.fetch(candidate.id, 0),
          weighted_sla_load: weighted_loads.fetch(candidate.id, 0)
        }
      end.transform_keys { |membership| membership.id.to_s }
    end

    def open_counts
      @open_counts ||= organization.tickets
        .where(status: OPEN_WORK_STATUSES, assignee_membership_id: candidate_ids)
        .group(:assignee_membership_id)
        .count
    end

    def weighted_loads
      @weighted_loads ||= begin
        weight_sql = PRIORITY_WEIGHTS.map do |priority, weight|
          "WHEN '#{priority}' THEN #{weight}"
        end.join(" ")

        organization.tickets
          .where(status: OPEN_WORK_STATUSES, assignee_membership_id: candidate_ids)
          .group(:assignee_membership_id)
          .pluck(:assignee_membership_id, Arel.sql("SUM(CASE priority #{weight_sql} ELSE 0 END)"))
          .to_h
      end
    end

    def candidate_ids
      @candidate_ids ||= candidates.map(&:id)
    end

    def no_candidate_decision
      Decision.new(
        policy_key: DEFAULT_POLICY,
        assignee: nil,
        scores: {},
        experiment_assignment: nil,
        reason: "no_eligible_agent"
      )
    end
  end
end
