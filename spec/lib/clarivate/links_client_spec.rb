describe Clarivate::LinksClient do
  subject(:links_client) { described_class.new }

  let(:ids) { %w(000081515000015 000346594100007) }
  let(:fields) { %w(doi pmid) }

  before do
    allow(Settings.WOS).to receive(:AUTH_CODE).and_return("YXR6OmZvb2Jhcg==\n") # atz:foobar
  end

  describe '#initialize' do
    context 'with no params' do
      it 'has defaults, including auth from Settings' do
        expect(links_client.host).to eq 'https://ws.isiknowledge.com'
        expect(links_client.username).to eq 'atz'
        expect(links_client.password).to eq 'foobar'
      end
    end
    context 'with params' do
      subject(:links_client) { described_class.new(username: 'leland', password: 'sunflower', host: 'http://proxy.us') }
      it 'accepts overrides' do
        expect(links_client.host).to eq 'http://proxy.us'
        expect(links_client.username).to eq 'leland'
        expect(links_client.password).to eq 'sunflower'
      end
    end
  end

  describe '#links' do
    it 'requires param' do
      expect { links_client.links }.to raise_error ArgumentError
    end

    context 'with param' do
      let(:response_xml) { File.read('spec/fixtures/clarivate/links_response.xml') }
      let(:links) { links_client.links(ids, fields: fields) }

      before do
        allow(links_client.send(:connection)).to receive(:post).with(any_args).and_return(double(body: response_xml))
      end

      it 'returns matching identifiers' do
        expect(links).to match a_hash_including(*ids)
        expect(links[ids[0]]).to match a_hash_including('pmid' => '10435530', 'doi' => '10.1118/1.598623')
        expect(links[ids[1]]).to match a_hash_including('doi' => '10.1002/2013GB004790')
      end
    end

    context 'no results found' do
      let(:response_xml) { File.read('spec/fixtures/clarivate/links_no_result_found.xml') }
      let(:ids) { ['MEDLINE:24452614'] }
      let(:links) { links_client.links(ids) }

      before do
        allow(links_client.send(:connection)).to receive(:post).with(any_args).and_return(double(body: response_xml))
      end
      it 'returns a Hash with id-keys' do
        expect(links.keys).to eq ids
      end
      it 'returns a Hash with Hash values' do
        expect(links.values.first).to be_an Hash
      end
      it 'Hash values are empty' do
        expect(links.values.first).to be_empty
      end
    end

    context 'empty results' do
      let(:response_xml) { File.read('spec/fixtures/clarivate/links_empty_results.xml') }
      let(:ids) { %w(A1972N549400003 A1976BW18000001) }
      let(:links) { links_client.links(ids) }

      before do
        allow(links_client.send(:connection)).to receive(:post).with(any_args).and_return(double(body: response_xml))
      end
      it 'returns a Hash with id-keys' do
        expect(links.keys).to eq ids
      end
      it 'returns a Hash with Hash values' do
        expect(links.values.first).to be_an Hash
      end
      it 'Hash values are empty' do
        expect(links.values.first).to be_empty
      end
    end
  end

  describe '#request_body' do
    let(:request_xml) { links_client.send(:request_body, ids, fields) }

    it 'returns well formed XML' do
      expect { Nokogiri::XML(request_xml) { |config| config.strict.noblanks } }.not_to raise_error
    end
    it 'contains the ids' do
      expect(request_xml).to include ids.first
    end
    it 'contains the fields' do
      expect(request_xml).to include fields.first
    end
  end

  describe '.working?' do
    context 'success', :vcr do
      it 'returns true when it works (has 2 results)' do
        expect(described_class.working?).to be true
      end
    end
    context 'failure' do
      it 'raises exceptions when it fails (no results)' do
        response_xml = File.read('spec/fixtures/clarivate/links_empty_results.xml')
        allow(links_client.send(:connection)).to receive(:post).with(any_args).and_return(double(body: response_xml))
        expect { described_class.working? }.to raise_error(RuntimeError)
      end
    end
  end
end
