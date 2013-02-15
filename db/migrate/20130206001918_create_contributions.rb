class CreateContributions < ActiveRecord::Migration
  def change
    create_table :contributions do |t|
      t.integer :author_id
      t.integer :cap_profile_id
      t.integer :publication_id
      t.string :confirmed_status
      t.string :highlight_ind

      t.timestamps
    end
  end
end