class CreateUsageEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :usage_events, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :tenant, null: false, foreign_key: true, type: :uuid
      t.string :idempotency_key, null: false
      t.string :event_type, null: false
      t.decimal :quantity, null: false, precision: 12, scale: 4
      t.datetime :occurred_at, null: false
      t.jsonb :metadata, null: false, default: {}

      t.timestamps
    end

    add_index :usage_events, :idempotency_key, unique: true
    add_index :usage_events, :occurred_at
  end
end
