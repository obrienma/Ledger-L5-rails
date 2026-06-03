class CreateInvoices < ActiveRecord::Migration[8.1]
  def change
    create_table :invoices, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :tenant, null: false, foreign_key: true, type: :uuid
      t.string :stripe_invoice_id
      t.string :status, null: false, default: "draft"
      t.integer :amount_cents, null: false, default: 0
      t.date :period_start, null: false
      t.date :period_end, null: false
      t.datetime :paid_at

      t.timestamps
    end

    add_index :invoices, :stripe_invoice_id, unique: true, where: "stripe_invoice_id IS NOT NULL"
  end
end
