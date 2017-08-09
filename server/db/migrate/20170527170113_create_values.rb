class CreateValues < ActiveRecord::Migration[5.1]
  def change
    create_table :values, id: false do |t|
      t.string :name, null: false
      t.timestamps
    end
    add_index :values, :name, unique: true
  end
end
