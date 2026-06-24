class CreateSchools < ActiveRecord::Migration[7.0]
  def change
    create_table :schools do |t|
      t.string :name, null: false
      t.string :email_suffix, null: false
      t.timestamps
    end
    add_index :schools, :email_suffix, unique: true
  end
end
