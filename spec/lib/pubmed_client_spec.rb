require 'spec_helper'

describe PubmedClient do

	let(:pubmed_client) {PubmedClient.new}

	describe "#fetch_records_for_pmid_list" do
		
		context "with valid pmid list of 4" do
			it "returns a list of 4 pubmed records " do
				VCR.use_cassette("pub_med_client_spec_returns_a_list") do
					expect(Nokogiri::XML(pubmed_client.fetch_records_for_pmid_list([211,589,591,960])).xpath('//PubmedArticle')).to have(4).items
				end
			end
		end

		context "with invalid pmid list" do
			it "returns an empty array" do
				VCR.use_cassette("pub_med_client_spec_returns_an_empty_array") do
					expect(Nokogiri::XML(pubmed_client.fetch_records_for_pmid_list([233333333333333,45555666666666])).xpath('//PubmedArticle')).to have(0).items
				end
			end
		end

	end
	

end