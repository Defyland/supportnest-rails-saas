class CreateRateLimitBuckets < ActiveRecord::Migration[8.1]
  def change
    create_table :rate_limit_buckets do |t|
      t.string :identifier_digest, null: false
      t.datetime :window_started_at, null: false
      t.integer :requests_count, null: false, default: 0
      t.datetime :expires_at, null: false

      t.timestamps
    end

    add_index :rate_limit_buckets, [ :identifier_digest, :window_started_at ], unique: true
    add_index :rate_limit_buckets, :expires_at
    add_check_constraint :rate_limit_buckets, "requests_count >= 0",
                         name: "rate_limit_buckets_requests_count_non_negative"
  end
end
