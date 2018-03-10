class AddUniqueConstraintToPublicationWosuid < ActiveRecord::Migration
  def change
    uids = WebOfScienceSourceRecord.group(:uid).having("count(uid) > 1").pluck(:uid)
    marked_for_death = []
    WebOfScienceSourceRecord.where(uid: uids).order(:created_at).group_by(&:uid).each do |_uid, recs|
      marked_for_death.concat(recs.map(&:id)[1..-1]) # skip the first (0th) record for each uid
    end
    WebOfScienceSourceRecord.delete(marked_for_death) # delete the rest, all at once

    remove_index :publications, :wos_uid # replace this with a UNIQUE index
    add_index :publications, :wos_uid, name: "index_publications_on_wos_uid", unique: true, using: :btree

    add_index :web_of_science_source_records, :source_fingerprint, unique: true, using: :btree
  end
end
