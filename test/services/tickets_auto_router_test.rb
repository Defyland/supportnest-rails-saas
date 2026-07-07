require "test_helper"
require "digest"

class TicketsAutoRouterTest < ActiveSupport::TestCase
  test "chooses the least-loaded active support member by default" do
    organization, agent_one, agent_two = create_support_team
    create_ticket(organization: organization, assignee: agent_one, sequence: 1)
    create_ticket(organization: organization, assignee: agent_one, sequence: 2)

    decision = Tickets::AutoRouter.call!(
      organization: organization,
      ticket_attributes: {
        requester_email: "customer@example.com",
        priority: "normal",
        inbox: "general"
      }
    )

    assert_equal "least-open-tickets", decision.policy_key
    assert_equal agent_two, decision.assignee
    assert_equal "default_policy", decision.reason
    assert_equal 2, decision.scores.fetch(agent_one.id.to_s).fetch(:open_ticket_count)
    assert_equal 0, decision.scores.fetch(agent_two.id.to_s).fetch(:open_ticket_count)
  end

  test "uses the SLA-priority experiment variant when it is assigned" do
    organization, agent_one, agent_two = create_support_team
    create_ticket(organization: organization, assignee: agent_one, sequence: 1, priority: "low")
    create_ticket(organization: organization, assignee: agent_one, sequence: 2, priority: "low")
    create_ticket(organization: organization, assignee: agent_two, sequence: 3, priority: "urgent")
    experiment = create_routing_experiment(organization)
    requester_email = subject_for_variant(experiment, "sla-priority")

    decision = Tickets::AutoRouter.call!(
      organization: organization,
      ticket_attributes: {
        requester_email: requester_email,
        priority: "urgent",
        inbox: "billing"
      }
    )

    assert_equal "sla-priority", decision.policy_key
    assert_equal agent_one, decision.assignee
    assert_equal "experiment_variant", decision.reason
    assert_equal "sla-priority", decision.experiment_assignment.experiment_variant.key
    assert_equal 2, decision.scores.fetch(agent_one.id.to_s).fetch(:weighted_sla_load)
    assert_equal 8, decision.scores.fetch(agent_two.id.to_s).fetch(:weighted_sla_load)
  end

  test "leaves the ticket unassigned when no active support member exists" do
    organization = Organization.create!(name: "Acme", slug: unique_slug("no-agent"))

    decision = Tickets::AutoRouter.call!(
      organization: organization,
      ticket_attributes: {
        requester_email: "customer@example.com",
        priority: "normal"
      }
    )

    assert_not decision.assigned?
    assert_equal "no_eligible_agent", decision.reason
  end

  test "ticket creation records routing evidence and assigns automatically" do
    organization, = create_support_team
    agent = organization.memberships.agent.first
    actor = agent

    ticket = Tickets::Create.call!(
      organization: organization,
      actor: actor,
      attributes: {
        subject: "Billing portal shows 500",
        description: "Customer sees a 500 on checkout confirmation.",
        requester_name: "Jamie Customer",
        requester_email: "jamie@example.com",
        priority: "urgent"
      }
    )

    assert_equal agent, ticket.assignee_membership

    audit_log = AuditLog.where(action: "ticket.created").last
    event = OutboundEvent.where(event_type: "ticket.created").last

    assert_equal "least-open-tickets", audit_log.metadata.dig("routing", "policy_key")
    assert_equal agent.id, audit_log.metadata.dig("routing", "assignee_membership_id")
    assert_equal "least-open-tickets", event.payload.dig("routing", "policy_key")
  end

  private

  def create_support_team
    organization = Organization.create!(name: "Acme", slug: unique_slug("router"))
    agent_one = create_membership(organization: organization, email: "agent-one@acme.test", role: "agent")
    agent_two = create_membership(organization: organization, email: "agent-two@acme.test", role: "agent")

    [ organization, agent_one, agent_two ]
  end

  def create_membership(organization:, email:, role:)
    raw_token, digest = Tokens::Issuer.issue(prefix: "sn_test_")

    organization.memberships.create!(
      email: email,
      full_name: email.split("@").first.titleize,
      role: role,
      state: "active",
      api_token_digest: digest,
      api_token_last_eight: raw_token.last(8)
    )
  end

  def create_ticket(organization:, assignee:, sequence:, priority: "normal")
    creator = assignee

    organization.tickets.create!(
      public_id: format("TCK-%06d", sequence),
      subject: "Existing ticket #{sequence}",
      description: "Workload fixture",
      requester_name: "Customer #{sequence}",
      requester_email: "customer-#{sequence}@example.com",
      created_by_membership: creator,
      assignee_membership: assignee,
      priority: priority
    )
  end

  def create_routing_experiment(organization)
    organization.experiments.create!(
      key: Tickets::AutoRouter::EXPERIMENT_KEY,
      name: "Ticket auto routing",
      status: "active"
    ).tap do |experiment|
      experiment.experiment_variants.create!(key: "least-open-tickets", name: "Least open tickets", weight: 50)
      experiment.experiment_variants.create!(key: "sla-priority", name: "SLA priority", weight: 50)
    end
  end

  def subject_for_variant(experiment, variant_key)
    variants = experiment.experiment_variants.order(:key).to_a
    total_weight = variants.sum(&:weight)

    1.upto(500) do |index|
      subject = "customer-#{index}@example.com"
      digest = Digest::SHA256.hexdigest("#{experiment.id}:#{subject}")
      bucket = digest[0, 16].to_i(16) % total_weight
      cumulative = 0
      selected = variants.find do |variant|
        cumulative += variant.weight
        bucket < cumulative
      end

      return subject if selected.key == variant_key
    end

    raise "Could not find subject for #{variant_key}"
  end
end
