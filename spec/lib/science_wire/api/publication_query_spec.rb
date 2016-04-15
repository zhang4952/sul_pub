require 'spec_helper'

describe ScienceWire::API::PublicationQuery do
  let(:client) do
    ScienceWire::Client.new(
      license_id: 'license', host: Settings.SCIENCEWIRE.HOST
    )
  end
  describe '#send_publication_query' do
    let(:fake_body) { '<xml></xml>' }
    it 'requests the publication query' do
      client.send_publication_query(fake_body)
      expect(a_post(
        '/PublicationCatalog/PublicationQuery?format=xml'
      ).with(body: fake_body)).to have_been_made
    end
  end
  describe '#retrieve_publication_query' do
    let(:queryId) { 'abc123' }
    it 'requests the publication query' do
      client.retrieve_publication_query(queryId)
      expect(a_get(
        "/PublicationCatalog/PublicationQuery/#{queryId}"
      ).with(
        query: {
          format: 'xml', page: 0, pageSize: 2_147_483_647, v: 'version/3'
        }
      )).to have_been_made
    end
  end
end
