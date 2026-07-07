require "test_helper"

class ExperimentTest < ActiveSupport::TestCase
  test "normalizes and validates tenant-scoped experiment keys" do
    organization = Organization.create!(name: "Acme", slug: unique_slug("exp"))

    experiment = organization.experiments.create!(key: " Ticket-Routing ", name: "Ticket routing")

    assert_equal "ticket-routing", experiment.key

    duplicate = organization.experiments.build(key: "ticket-routing", name: "Duplicate")

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:key], "has already been taken"
  end

  test "requires valid variant weights" do
    organization = Organization.create!(name: "Acme", slug: unique_slug("variant"))
    experiment = organization.experiments.create!(key: "ticket-routing", name: "Ticket routing")

    variant = experiment.experiment_variants.build(key: "control", name: "Control", weight: 0)

    assert_not variant.valid?
    assert_includes variant.errors[:weight], "must be greater than 0"
  end
end
