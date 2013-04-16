class SourceRecord < ActiveRecord::Base
  attr_accessible :human_readable_title, :lock_version, :original_source_id, :source_data, :source_name, :source_data_type, :is_active, :is_local_only, :year, :publication_id
  has_many :publications_source_records
  belongs_to :publication
end
