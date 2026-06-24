class CreateOrders < ActiveRecord::Migration[7.0]
  def change
    create_table :orders do |t|
      t.integer :textbook_id, null: false
      t.integer :buyer_id, null: false
      t.integer :seller_id, null: false
      t.string :status, default: 'pending'
      t.datetime :buyer_confirmed_at
      t.datetime :seller_confirmed_at
      t.datetime :completed_at
      t.timestamps
    end
    add_index :orders, :textbook_id
    add_index :orders, :buyer_id
    add_index :orders, :seller_id
  end
end
