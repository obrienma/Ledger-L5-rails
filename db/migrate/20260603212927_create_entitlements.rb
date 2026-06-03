class CreateEntitlements < ActiveRecord::Migration[8.1]
  def change
    create_table :entitlements, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :tenant, null: false, foreign_key: true, type: :uuid, index: { unique: true }
      t.boolean :throttled, null: false, default: false
      t.datetime :throttled_at

      t.timestamps
    end
  end
end
