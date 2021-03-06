class UserSubmittedSourceRecord < ActiveRecord::Base
  validates :source_fingerprint, uniqueness: true
  belongs_to :publication, inverse_of: :user_submitted_source_records

  before_save do
    self.source_fingerprint = Digest::SHA2.hexdigest(source_data) if source_data_changed?
  end

  def self.find_or_initialize_by_source_data(data)
    UserSubmittedSourceRecord.find_or_initialize_by source_fingerprint: Digest::SHA2.hexdigest(data) do |r|
      r.source_data = data
    end
  end
end
