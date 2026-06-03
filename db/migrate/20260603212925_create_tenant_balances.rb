class CreateTenantBalances < ActiveRecord::Migration[8.1]
  def change
    create_table :tenant_balances, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :tenant, null: false, foreign_key: true, type: :uuid, index: { unique: true }
      t.decimal :current_usage, null: false, default: 0, precision: 12, scale: 4
      t.date :period_start, null: false
      t.date :period_end, null: false

      t.timestamps
    end
  end
end
