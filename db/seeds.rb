if Organization.exists?
  puts "SupportNest seed skipped: organizations already exist."
else
  result = Organizations::Bootstrap.call!(
    organization_attributes: {
      name: "Acme Support",
      slug: "acme-support",
      plan: "growth",
      seat_limit: 10,
      inbox_limit: 4,
      ticket_limit: 1000
    },
    owner_attributes: {
      email: "owner@acme.test",
      full_name: "Owner Admin"
    }
  )

  puts "Seeded organization #{result.organization.slug}"
  puts "Owner token: #{result.api_token}"
end
#   end
