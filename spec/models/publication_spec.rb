require 'spec_helper'

describe Publication do
  let(:publication) { FactoryGirl.create :publication }
  let(:author) {FactoryGirl.create :author }

  let(:pub_hash) {{title: "some title",
                   year: 1938,
                   issn: '32242424',
                   pages: '34-56',
                   author: [{name: "jackson joe"}],
                   authorship: [{sul_author_id: author.id, status: "denied", visibility: "public", featured: true} ],
                   identifier: [{:type => "x", :id => "y", :url => "z"}]
                }}

  describe "test pub hash syncing for new object" do
    subject do
      p = Publication.new
      p.pub_hash = pub_hash
      p.save
      p
    end

    it "should rebuild identifiers" do
      expect(subject.pub_hash[:identifier].length).to be > 0
      expect(subject.pub_hash[:sulpubid]).to eq(subject.id.to_s)
      expect(subject.pub_hash[:identifier]).to include(:type => "SULPubId", :id => subject.id.to_s, :url => "http://sulcap.stanford.edu/publications/#{subject.id}")
      expect(subject.pub_hash[:identifier]).to_not include(:type => "SULPubId", :url => "http://sulcap.stanford.edu/publications/")
      expect(subject.pub_hash[:identifier]).to include(:type => "x", :id => "y", :url => "z")
    end


  end

  describe "pubhash syncing" do
    subject do
      publication.pub_hash = pub_hash.dup
      publication.update_any_new_contribution_info_in_pub_hash_to_db
      publication.save
      publication.reload
    end

    it "should set the last updated value to match the database row" do
      expect(Time.parse(subject.pub_hash[:last_updated])).to be >= (Time.now - 1.minutes)
    end

    it "should rebuild authors" do
      expect(subject.contributions.entries.size).to eq(1)
      expect(subject.pub_hash[:authorship].length).to be > 0
      expect(subject.pub_hash[:authorship]).to include(subject.contributions.first.to_pub_hash)
    end

    it "should rebuild identifiers" do
      expect(subject.pub_hash[:identifier].length).to be > 0
      expect(subject.pub_hash[:sulpubid]).to eq(subject.id.to_s)
      expect(subject.pub_hash[:identifier]).to include(:type => "SULPubId", :id => subject.id.to_s, :url => "http://sulcap.stanford.edu/publications/#{subject.id}")
      expect(subject.pub_hash[:identifier]).to include(:type => "x", :id => "y", :url => "z")
    end
  end

  describe "sync_identifiers_in_pub_hash_to_db" do
    it "should sync identifiers in the pub hash to the database" do
      publication.pub_hash = { :identifier => [ { :type => "x", :id => "y", :url => "z" } ] }
      publication.sync_identifiers_in_pub_hash_to_db
      i = PublicationIdentifier.last
      expect(i.identifier_type).to eq("x")
      expect(publication.publication_identifiers(true)).to include(i)
    end

    it "should not persist SULPubIds" do
      publication.pub_hash = { :identifier => [ { :type => "SULPubId", :id => "y", :url => "z" } ] }
      expect {
        publication.sync_identifiers_in_pub_hash_to_db
      }.to_not change(publication, :publication_identifiers)
    end

    it "updates existing ids with new values" do
      publication.pub_hash = { :identifier => [ { :type => "x", :id => "y", :url => "z" } ] }
      publication.sync_identifiers_in_pub_hash_to_db
      publication.pub_hash = { :identifier => [ { :type => "x", :id => "y2", :url => "z2" } ] }
      publication.sync_identifiers_in_pub_hash_to_db
      ids = PublicationIdentifier.where(:publication_id => publication.id).all
      expect(ids.size).to eq(1)
      expect(ids.first.identifier_type).to eq('x')
      expect(ids.first.identifier_value).to eq('y2')
      expect(ids.first.identifier_uri).to eq('z2')
    end

    it "deletes ids from the database that are not longer in the pub_hash" do
      publication.pub_hash = { :identifier => [ { :type => "x", :id => "y", :url => "z" } ] }
      publication.sync_identifiers_in_pub_hash_to_db
      publication.pub_hash = { :identifier => [ { :type => "a", :id => "b", :url => "c" } ] }
      publication.sync_identifiers_in_pub_hash_to_db
      expect(PublicationIdentifier.where(:publication_id => publication.id, :identifier_type => 'x').count).to eq(0)
      expect(PublicationIdentifier.where(:publication_id => publication.id, :identifier_type => 'a').count).to eq(1)
    end

    it "does not delete legacy_cap_pub_id when missing from the incoming pub_hash" do
      publication.pub_hash = { :identifier => [ { :type => "legacy_cap_pub_id", :id => "258214" } ] }
      publication.sync_identifiers_in_pub_hash_to_db
      publication.pub_hash = { :identifier => [ { :type => "another", :id => "id", :url => "with a url" } ] }
      publication.sync_identifiers_in_pub_hash_to_db
      expect(PublicationIdentifier.where(:publication_id => publication.id, :identifier_type => 'legacy_cap_pub_id').count).to eq(1)
      expect(PublicationIdentifier.where(:publication_id => publication.id, :identifier_type => 'another').count).to eq(1)
    end
  end

  describe "update_any_new_contribution_info_in_pub_hash_to_db" do
    it "should sync existing authors in the pub hash to contributions in the db" do
      publication.pub_hash = { :authorship => [ { :status => "x", :sul_author_id => author.id }]}
      publication.update_any_new_contribution_info_in_pub_hash_to_db
      publication.save
      expect(publication.contributions.size).to eq(1)
      c = publication.contributions.last
      expect(c.author).to eq(author)
      expect(c.status).to eq("x")
    end

    it "should update attributions of existing contributions to the database" do
      publication.contributions.build_or_update author, :status => "y"
      publication.pub_hash = { :authorship => [ { :status => "z", :sul_author_id => author.id }]}
      publication.update_any_new_contribution_info_in_pub_hash_to_db
      publication.save
      expect(publication.contributions.size).to eq(1)
      c = publication.contributions(true).last
      expect(c.author).to eq(author)
      expect(c.status).to eq("z")
    end

    it "should look up authors by their cap profile id" do
      author.cap_profile_id = "abc"
      author.save

      publication.pub_hash = { :authorship => [ { :status => "z", :cap_profile_id => author.cap_profile_id }]}
      publication.update_any_new_contribution_info_in_pub_hash_to_db

      publication.save
      expect(publication.contributions.size).to eq(1)
      c = publication.contributions.last
      expect(c.author).to eq(author)
      expect(c.status).to eq("z")
    end

    it "should ignore unknown authors" do
      publication.pub_hash = { :authorship => [ { :status => "ignored", :cap_profile_id => "doesnt_exist" }]}
      publication.update_any_new_contribution_info_in_pub_hash_to_db
      publication.save
      expect(publication.contributions).to be_empty
    end
  end

  describe "add_any_pubmed_data_to_hash" do
    it "should add mesh and abstract data if available" do
      publication.pmid = 1
      allow(PubmedSourceRecord).to receive(:get_pubmed_hash_for_pmid).with(1).and_return :mesh_headings => "x", :abstract => "y"

      publication.add_any_pubmed_data_to_hash

      expect(publication.pub_hash[:mesh_headings]).to eq("x")
      expect(publication.pub_hash[:abstract]).to eq("y")

    end

    it "should ignore records without a pmid" do
      publication.add_any_pubmed_data_to_hash
    end

    it "should ignore records with an empty pubmed record" do
      publication.pmid = 1
      allow(PubmedSourceRecord).to receive(:get_pubmed_hash_for_pmid).with(1).and_return nil

      publication.add_any_pubmed_data_to_hash
    end
  end

  describe "delete!" do
    it "should mark the publication deleted" do
      publication.delete!
      expect(publication.deleted).to be_truthy
      expect(publication).to be_deleted
    end
  end

  describe "pubhash_needs_update" do
    it "should mark the pub hash as modified" do
      publication.pubhash_needs_update!
      expect(publication).to be_pubhash_needs_update
    end
  end

  describe "update_formatted_citations" do
    it "should update the apa, mla, and chicago citations" do
      allow(publication).to receive(:pub_hash).and_return({})
      apa = double()
      mla = double()
      chicago = double()
      expect_any_instance_of(PubHash).to receive(:to_apa_citation).and_return(apa)
      expect_any_instance_of(PubHash).to receive(:to_mla_citation).and_return(mla)
      expect_any_instance_of(PubHash).to receive(:to_chicago_citation).and_return(chicago)
      publication.update_formatted_citations
      expect(publication.pub_hash[:apa_citation]).to eq(apa)
      expect(publication.pub_hash[:mla_citation]).to eq(mla)
      expect(publication.pub_hash[:chicago_citation]).to eq(chicago)
    end
  end

  describe "contributions.build_or_update" do
    it "should add a contribution" do
      c = publication.contributions.build_or_update author, :status => "x"
      expect(c.author).to eq(author)
      expect(c.status).to eq("x")

    end

    it "should update a contribution record if the association exists" do
      publication.contributions.build_or_update author

      c = publication.contributions.build_or_update author, :status => "y"
      expect(c.author).to eq(author)
      expect(c.status).to eq("y")

    end
  end

  describe ".build_new_manual_publication" do
    it "should add a publication" do
      pub = Publication.build_new_manual_publication("some where", pub_hash, "some string")
      pub.save!
      expect(pub.authors.size).to eq(1)
    end

    it "should refuse to add a publication with the same source record" do

      pub = Publication.build_new_manual_publication("some where", pub_hash, "some string")

      pub.save!

      expect {
        Publication.build_new_manual_publication("some where", pub_hash, "some string")
      }.to raise_exception #sqlite 3.6 is inconsistent in raising the right kind of exception (ActiveRecord::RecordNotUnique)
    end

    it "should create a publication if a publication for that source record doesn't exist" do
      UserSubmittedSourceRecord.create :source_data => "some string"

      expect {
      pub = Publication.build_new_manual_publication("some where", pub_hash, "some string")
      pub.save!
      }.not_to raise_exception
    end
  end

  describe "update_manual_pub_from_pub_Hash" do
    it "should update the user submitted source record with the new content" do

      pub = Publication.build_new_manual_publication("some where", {:a => :b}, "some string")
      pub.update_manual_pub_from_pub_hash({:b => :c}, "some where", "some other string")
      pub.save!
      expect(pub.user_submitted_source_records.first[:source_data]).to eq("some other string")
      expect(pub.pub_hash).to include(:b => :c)
    end

    it "should raise an exception if you try to update the record to match an existing source record" do

      pub = Publication.build_new_manual_publication("some where", {:a => :b}, "some string")
      pub.save

      pub = Publication.build_new_manual_publication("some where", {:b => :c}, "some other string")
      pub.update_manual_pub_from_pub_hash({:b => :c}, "some where", "some string")
      expect {
        pub.save!
      }.to raise_exception #sqlite 3.6 is inconsistent in raising the right kind of exception (ActiveRecord::RecordNotUnique)
    end
  end

  describe ".find_by_doi" do
    it "returns an array of Publications that have this doi" do
      publication.pub_hash = { :identifier => [ { :type => "doi", :id => "10.1016/j.mcn.2012.03.008", :url => "http://dx.doi.org/10.1016/j.mcn.2012.03.008" } ] }
      publication.sync_identifiers_in_pub_hash_to_db
      res = Publication.find_by_doi '10.1016/j.mcn.2012.03.008'
      expect(res.size).to eq(1)
      expect(res.first.id).to eq(publication.id)
    end

    it "returns an empty array if the doi isn't found" do
      expect(Publication.find_by_doi 'does not exist').to be_empty
    end
  end

  describe "#authoritative_pmid_source?" do
    let(:pub) { Publication.new }

    it "returns true if the pub has a provenance of 'pubmed'" do
      pub.pub_hash = { :provenance => 'pubmed' }
      expect(pub).to be_authoritative_pmid_source
    end

    it "returns true if the pub has a provenance of 'sciencewire'" do
      pub.pub_hash = { :provenance => 'sciencewire' }
      expect(pub).to be_authoritative_pmid_source
    end

    it "returns false if the pub does not have a provanance of 'pubmed' or 'sciencewire'" do
      pub.pub_hash = { :provenance => 'cap' }
      expect(pub).to_not be_authoritative_pmid_source
    end
  end

end
