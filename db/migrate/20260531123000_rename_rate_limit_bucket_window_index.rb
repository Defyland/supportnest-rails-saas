class RenameRateLimitBucketWindowIndex < ActiveRecord::Migration[8.1]
  OLD_INDEX_NAME = "idx_on_identifier_digest_window_started_at_a1775b6ae6"
  NEW_INDEX_NAME = "index_rate_limit_buckets_on_identifier_window"

  def change
    rename_index :rate_limit_buckets, OLD_INDEX_NAME, NEW_INDEX_NAME
  end
end
