class CreateExperiments < ActiveRecord::Migration[8.1]
  def change
    create_table :experiments do |t|
      t.references :organization, null: false, foreign_key: true
      t.string :key, null: false
      t.string :name, null: false
      t.string :status, default: "draft", null: false

      t.timestamps
    end

    add_index :experiments, %i[organization_id key], unique: true
    add_check_constraint :experiments,
      "status IN ('draft', 'active', 'paused', 'archived')",
      name: "experiments_status_valid"

    create_table :experiment_variants do |t|
      t.references :experiment, null: false, foreign_key: true
      t.string :key, null: false
      t.string :name, null: false
      t.integer :weight, default: 1, null: false

      t.timestamps
    end

    add_index :experiment_variants, %i[experiment_id key], unique: true
    add_check_constraint :experiment_variants, "weight > 0", name: "experiment_variants_weight_positive"

    create_table :experiment_assignments do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :experiment, null: false, foreign_key: true
      t.references :experiment_variant, null: false, foreign_key: true
      t.string :subject_key, null: false
      t.string :bucket_key_digest, null: false
      t.integer :bucket_value, null: false
      t.datetime :assigned_at, null: false
      t.json :context, default: {}, null: false

      t.timestamps
    end

    add_index :experiment_assignments, %i[experiment_id subject_key], unique: true
    add_index :experiment_assignments, %i[organization_id subject_key]
    add_check_constraint :experiment_assignments,
      "bucket_value >= 0",
      name: "experiment_assignments_bucket_value_non_negative"

    create_table :experiment_conversions do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :experiment_assignment, null: false, foreign_key: true
      t.string :event_name, null: false
      t.string :idempotency_key, null: false
      t.json :metadata, default: {}, null: false
      t.datetime :occurred_at, null: false

      t.timestamps
    end

    add_index :experiment_conversions, %i[organization_id idempotency_key], unique: true
    add_index :experiment_conversions, %i[experiment_assignment_id event_name]
  end
end
