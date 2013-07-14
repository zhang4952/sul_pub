require 'spec_helper'

describe SulBib::API do
  
  let(:publication) { create :publication }
  let(:author) { create :author }
  let!(:publication_with_contributions) { create :publication_with_contributions, contributions_count:2  }    
  let(:existing_contrib) {create :contribution, publication: publication_with_contributions, author: author, visibility: "public", status: "approved"}
  let(:headers) {{ 'HTTP_CAPKEY' => '***REMOVED***', 'CONTENT_TYPE' => 'application/json' }}
  let(:valid_json_for_post) {{sul_author_id: author.id, status: "denied", sul_pub_id: publication.id}.to_json}
  let(:valid_json_for_pub_with_contributions) {{sul_author_id: author.id, status: "denied", visibility: "private", sul_pub_id: publication_with_contributions.id}.to_json}
  let(:valid_json_for_sw_id) {{sul_author_id: author.id, status: "denied", visibility: "private", sw_id: 10379039}.to_json}
  let(:valid_json_for_pubmed_id) {{sul_author_id: author.id, status: "denied", visibility: "private", pmid: 23684686}.to_json}
  

  describe "POST /authorship" do

    context "when post is valid " do
      
      it 'increases number of contribution records by one' do
        expect {
            post "/authorship", valid_json_for_post, headers
          }.to change(Contribution, :count).by(1)
      end
      it 'increases number of contribution records, where records already exist, by one' do
        expect {
            post "/authorship", valid_json_for_pub_with_contributions, headers
          }.to change(Contribution, :count).from(2).to(3)
      end
      it "responds with 200" do 
        post "/authorship", valid_json_for_pub_with_contributions, headers
        response.status.should == 201
      end
      it "adds the authorship entry to the pub_hash for the publication" do
        post "/authorship", valid_json_for_pub_with_contributions, headers
        publication_with_contributions.reload
        publication_with_contributions.pub_hash[:authorship].any? { |entry| entry[:sul_author_id] == author.id }.should be_true
      end
      it 'creates a new authorship record without overwriting existing authorship records' do
        post "/authorship", valid_json_for_pub_with_contributions, headers
        publication_with_contributions.contributions.should have(3).items
      end
      it 'creates a contribution record with matching status' do       
        post "/authorship", valid_json_for_pub_with_contributions, headers
        Contribution.where(publication_id: publication_with_contributions.id, author_id: author.id).first.status.should == 'denied'
      end
      it 'creates a contribution record with matching visibility' do       
        post "/authorship", valid_json_for_pub_with_contributions, headers
        Contribution.where(publication_id: publication_with_contributions.id, author_id: author.id).first.visibility.should == 'private'
      end
      it 'should not create more than one contribution ' do
        post "/authorship", valid_json_for_pub_with_contributions, headers
       # puts "the count: " + Contribution.where(publication_id: publication_with_contributions.id, author_id: author.id).count.to_s
        count = Contribution.where(publication_id: publication_with_contributions.id, author_id: author.id).count
        count.should eq 1
      end     
      it 'increases number of contribution records for specified publication by one' do
        expect {
            post "/authorship", valid_json_for_pub_with_contributions, headers
          }.to change(publication_with_contributions.contributions, :count).by(1)
      end
      it "should update status of an existing contribution" do
        expect {
          post "/authorship", valid_json_for_pub_with_contributions, headers
        }.to change {existing_contrib.reload.status}
      end
      it "should update visibility of an existing contribution" do
        expect {
          post "/authorship", valid_json_for_pub_with_contributions, headers
        }.to change {existing_contrib.reload.visibility}
      end
      it "should not create a new contribution if matching one exists" do 
        existing_contrib
        expect {
            post "/authorship", valid_json_for_pub_with_contributions, headers
          }.to_not change(Contribution, :count)
      end

      it "updates the pub hash contribution visiblity if contribution already exists"
      it "updates the pub hash contribution status if contribution already exists"
      it "updates the pub hash contribution featured flag if contribution already exists"
      it "creates the correct number of contributions in pub_hash"
      it "works with cap_profile_id"
      it "adds pub with proper identifiers section"

      it "adds pub for pubmed_id not already in system" do
        post "/authorship", valid_json_for_pubmed_id, headers
        response.status.should == 201
        new_pub = Publication.last
        response.body.should == new_pub.pub_hash.to_json
        result = JSON.parse(response.body)
        result["pmid"].should == "23684686"
        result["authorship"].should be
        Contribution.where(publication_id: new_pub.id, author_id: author.id).first.status.should == 'denied'
      end

      it " adds pub for sciencewire_id not already in system " do 
        post "/authorship", valid_json_for_sw_id, headers
        response.status.should == 201
        new_pub = Publication.last
        response.body.should == new_pub.pub_hash.to_json
        result = JSON.parse(response.body)
        result["sw_id"].should == "10379039"
        Contribution.where(publication_id: new_pub.id, author_id: author.id).first.status.should == 'denied'
        result["authorship"].should be
        result["authorship"][0]["sul_author_id"].should == author.id
        
        #Contribution.where(publication_id: new_pub.id, author_id: author.id).first.status.should == 'denied'
      end

    end # end of the context

  end  # end of the describe

  
end
