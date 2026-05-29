require "test_helper"

class OrganizationTest < ActiveSupport::TestCase
  test "normalizes the slug before validation" do
    organization = Organization.create!(name: "Acme Support Unit", slug: "Acme Support Unit")

    assert_equal "acme-support-unit", organization.slug
  end

  test "enforces the unique slug index at the database layer" do
    slug = unique_slug("acme")
    Organization.create!(name: "Acme", slug: slug)

    assert_raises(ActiveRecord::RecordNotUnique) do
      Organization.insert_all!([
        {
          name: "Duplicate",
          slug: slug,
          plan: "starter",
          state: "active",
          seat_limit: 5,
          inbox_limit: 2,
          ticket_limit: 500,
          current_month_ticket_count: 0,
          created_at: Time.current,
          updated_at: Time.current
        }
      ])
    end
  end

  test "enforces positive limits at the database layer" do
    assert_raises(ActiveRecord::StatementInvalid) do
      Organization.insert_all!([
        {
          name: "Invalid",
          slug: unique_slug("invalid"),
          plan: "starter",
          state: "active",
          seat_limit: 0,
          inbox_limit: 2,
          ticket_limit: 500,
          current_month_ticket_count: 0,
          next_ticket_sequence: 1,
          created_at: Time.current,
          updated_at: Time.current
        }
      ])
    end
  end

  test "enforces organization enum values at the database layer" do
    assert_raises(ActiveRecord::StatementInvalid) do
      Organization.insert_all!([
        {
          name: "Invalid",
          slug: unique_slug("invalid-plan"),
          plan: "legacy",
          state: "active",
          seat_limit: 5,
          inbox_limit: 2,
          ticket_limit: 500,
          current_month_ticket_count: 0,
          next_ticket_sequence: 1,
          created_at: Time.current,
          updated_at: Time.current
        }
      ])
    end
  end
end
