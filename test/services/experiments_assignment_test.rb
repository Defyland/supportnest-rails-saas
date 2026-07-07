require "test_helper"

class ExperimentsAssignmentTest < ActiveSupport::TestCase
  test "assigns a stable weighted variant for the same tenant subject" do
    organization = create_organization
    experiment = create_experiment(organization)

    first = Experiments::Assign.call!(
      organization: organization,
      experiment_key: "ticket-routing",
      subject_key: "customer-123",
      context: { "inbox" => "billing" }
    )
    second = Experiments::Assign.call!(
      organization: organization,
      experiment_key: "ticket-routing",
      subject_key: "customer-123",
      context: { "inbox" => "changed" }
    )

    assert_equal first.id, second.id
    assert_equal first.experiment_variant_id, second.experiment_variant_id
    assert_equal({ "inbox" => "billing" }, first.reload.context)
    assert_includes experiment.experiment_variants.pluck(:id), first.experiment_variant_id
  end

  test "preserves existing assignments after variant weights change" do
    organization = create_organization
    experiment = create_experiment(organization)

    assignment = Experiments::Assign.call!(
      organization: organization,
      experiment_key: experiment.key,
      subject_key: "customer-456"
    )

    experiment.experiment_variants.find_by!(key: "least-open-tickets").update!(weight: 10_000)
    experiment.experiment_variants.find_by!(key: "sla-priority").update!(weight: 1)

    reassignment = Experiments::Assign.call!(
      organization: organization,
      experiment_key: experiment.key,
      subject_key: "customer-456"
    )

    assert_equal assignment.id, reassignment.id
    assert_equal assignment.experiment_variant_id, reassignment.experiment_variant_id
  end

  test "rejects inactive experiments and experiments without two variants" do
    organization = create_organization
    paused = create_experiment(organization, key: "paused-routing", status: "paused")

    assert_raises ActiveRecord::RecordNotFound do
      Experiments::Assign.call!(
        organization: organization,
        experiment_key: paused.key,
        subject_key: "customer-789"
      )
    end

    incomplete = organization.experiments.create!(key: "incomplete-routing", name: "Incomplete", status: "active")
    incomplete.experiment_variants.create!(key: "control", name: "Control", weight: 1)

    error = assert_raises ActiveRecord::RecordInvalid do
      Experiments::Assign.call!(
        organization: organization,
        experiment_key: incomplete.key,
        subject_key: "customer-789"
      )
    end

    assert_includes error.record.errors[:experiment_variants], "must include at least 2 active choices"
  end

  test "records conversions idempotently for an assigned subject" do
    organization = create_organization
    experiment = create_experiment(organization)
    assignment = Experiments::Assign.call!(
      organization: organization,
      experiment_key: experiment.key,
      subject_key: "customer-321"
    )

    first = Experiments::Convert.call!(
      organization: organization,
      experiment_key: experiment.key,
      subject_key: assignment.subject_key,
      event_name: "ticket_resolved",
      idempotency_key: "ticket:TCK-000001:resolved",
      metadata: { "ticket_id" => "TCK-000001" }
    )
    second = Experiments::Convert.call!(
      organization: organization,
      experiment_key: experiment.key,
      subject_key: assignment.subject_key,
      event_name: "ticket_resolved",
      idempotency_key: "ticket:TCK-000001:resolved",
      metadata: { "ticket_id" => "TCK-000001", "retry" => true }
    )

    assert_equal first.id, second.id
    assert_equal assignment.id, first.experiment_assignment_id
    assert_equal({ "ticket_id" => "TCK-000001" }, first.reload.metadata)
  end

  private

  def create_organization
    Organization.create!(name: "Acme", slug: unique_slug("experiment"))
  end

  def create_experiment(organization, key: "ticket-routing", status: "active")
    organization.experiments.create!(key: key, name: "Ticket routing", status: status).tap do |experiment|
      experiment.experiment_variants.create!(key: "least-open-tickets", name: "Least open tickets", weight: 50)
      experiment.experiment_variants.create!(key: "sla-priority", name: "SLA priority", weight: 50)
    end
  end
end
