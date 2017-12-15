class WosSourceRecordIntegerPmid < ActiveRecord::Migration
  def up
    change_column :web_of_science_source_records, :pmid, :integer
  end

  def down
    change_column :web_of_science_source_records, :pmid, :string
  end
end
