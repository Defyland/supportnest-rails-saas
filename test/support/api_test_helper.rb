module ApiTestHelper
  def json_response
    JSON.parse(response.body)
  end

  def auth_headers(token, extra = {})
    {
      "Authorization" => "Bearer #{token}",
      "X-Correlation-ID" => "test-correlation-id"
    }.merge(extra)
  end

  def bootstrap_organization(slug:, name: "Acme Support", owner_email: nil, organization_attributes: {})
    owner_email ||= "owner-#{slug}@acme.test"

    post "/v1/organizations", params: {
      organization: {
        name: name,
        slug: slug,
        plan: "starter"
      }.merge(organization_attributes),
      owner: {
        email: owner_email,
        full_name: "Owner Admin"
      }
    }, as: :json

    assert_response :created
    json_response
  end
end
