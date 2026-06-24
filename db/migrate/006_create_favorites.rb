class CreateFavorites < ActiveRecord::Migration[7.0]
  def change
    create_table :favorites do |t|
      t.integer :user_id, null: false
      t.integer :textbook_id, null: false
      t.timestamps
    end
    add_index :favorites, [:user_id, :textbook_id], unique: true
    add_index :favorites, :textbook_id
  end
end
