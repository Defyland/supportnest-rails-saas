class AddApiTokenLifecycleToMemberships < ActiveRecord::Migration[8.1]
  def up
    add_column :memberships, :api_token_expires_at, :datetime
    add_column :memberships, :api_token_revoked_at, :datetime
    add_index :memberships, :api_token_expires_at

    Membership.reset_column_information
    Membership.update_all(api_token_expires_at: 90.days.from_now)

    change_column_null :memberships, :api_token_expires_at, false
    add_check_constraint :memberships, "api_token_expires_at > created_at",
                         name: "memberships_api_token_expires_after_creation"
    add_check_constraint :memberships, "api_token_revoked_at IS NULL OR api_token_revoked_at >= created_at",
                         name: "memberships_api_token_revoked_after_creation"
  end

  def down
    remove_check_constraint :memberships, name: "memberships_api_token_revoked_after_creation"
    remove_check_constraint :memberships, name: "memberships_api_token_expires_after_creation"
    remove_index :memberships, :api_token_expires_at
    remove_column :memberships, :api_token_revoked_at
    remove_column :memberships, :api_token_expires_at
  end
end
