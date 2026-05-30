class CreateNotifications < ActiveRecord::Migration[8.1]
  def change
    create_table :notifications do |t|
      t.references :store, null: false, foreign_key: true
      t.references :user, foreign_key: true
      t.string :event, null: false
      t.string :title, null: false
      t.text :body
      t.json :metadata
      t.datetime :read_at

      t.timestamps
    end

    add_index :notifications, [ :store_id, :created_at ]
    add_index :notifications, [ :store_id, :user_id, :read_at ]
    add_index :notifications, [ :store_id, :event ]
  end
end
