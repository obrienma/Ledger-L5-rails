class CreateTenants < ActiveRecord::Migration[8.1]
  def change
    create_table :tenants, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.string :name, null: false
      t.string :plan, null: false, default: "free"
      t.string :status, null: false, default: "active"
      t.string :stripe_customer_id

      t.timestamps
    end
  end
end
