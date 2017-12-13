class WosSrcRecordMediumText < ActiveRecord::Migration
  def up
    change_column :web_of_science_source_records, :source_data, :mediumtext
  end

  def down
    change_column :web_of_science_source_records, :source_data, :text
  end
end
