class CreateTextbooks < ActiveRecord::Migration[7.0]
  def change
    create_table :textbooks do |t|
      t.string :title, null: false
      t.string :isbn, null: false
      t.decimal :original_price, precision: 10, scale: 2, null: false
      t.decimal :selling_price, precision: 10, scale: 2, null: false
      t.integer :condition_level, default: 0
      t.string :course_name
      t.text :description
      t.integer :seller_id, null: false
      t.string :status, default: 'available'
      t.timestamps
    end
    add_index :textbooks, :isbn
    add_index :textbooks, :seller_id
    add_index :textbooks, :course_name
  end
end
