require "test_helper"
require "yaml"

class SecurityAuthorizerTest < ActiveSupport::TestCase
  test "loads permissions from the versioned authorization matrix" do
    matrix = YAML.safe_load_file(Rails.root.join("config/authorization_matrix.yml")).fetch("roles")

    assert_equal matrix.keys.sort, Security::Authorizer::PERMISSIONS.keys.map(&:to_s).sort

    matrix.each do |role, permissions|
      assert_equal permissions.sort, Security::Authorizer::PERMISSIONS.fetch(role.to_sym).map(&:to_s).sort
    end
  end

  test "keeps authorization roles aligned with membership enum roles" do
    assert_equal Membership.roles.keys.sort, Security::Authorizer::PERMISSIONS.keys.map(&:to_s).sort
  end

  test "allows and rejects permissions according to the matrix" do
    viewer = Membership.new(role: "viewer")

    assert_nothing_raised do
      Security::Authorizer.authorize!(viewer, :tickets_read)
    end

    error = assert_raises(Security::AuthorizationError) do
      Security::Authorizer.authorize!(viewer, :tickets_create)
    end

    assert_equal "viewer cannot perform tickets_create.", error.message
  end
end
