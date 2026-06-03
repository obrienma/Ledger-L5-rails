class CreateApiKeys < ActiveRecord::Migration[8.1]
  def change
    create_table :api_keys, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :tenant, null: false, foreign_key: true, type: :uuid
      t.string :token_digest, null: false
      t.string :name, null: false
      t.boolean :active, null: false, default: true

      t.timestamps
    end
  end
end
