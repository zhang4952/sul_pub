
RSpec.describe WebOfScienceSourceRecord, type: :model do
  let(:encoded_records) { File.read('spec/fixtures/wos_client/wos_encoded_records.html') }
  let(:wos_records) { WebOfScience::Records.new(encoded_records: encoded_records) }
  let(:wos_record) { wos_records.first }
  let(:wos_src_rec) { described_class.new(source_data: wos_record.to_xml) }

  context 'initialize a new record' do
    it 'can be created from a WOS source record' do
      expect(wos_src_rec).to be_an described_class
    end
    it 'cannot be created without a WOS source record' do
      expect { described_class.new }.to raise_error(RuntimeError)
    end
    it 'extracts a UID from a WOS source record' do
      expect(wos_src_rec.uid).to be_an String
    end
    it 'extracts a database identifier from a WOS source record' do
      expect(wos_src_rec.database).to be_an String
    end
    it 'extracts a source_fingerprint from a WOS source record' do
      expect(wos_src_rec.source_fingerprint).to be_an String
    end
    it 'sets active true' do
      expect(wos_src_rec.active).to be true
    end
  end

  context 'sets identifiers' do
    before do
      identifiers = WebOfScience::Identifiers.new(wos_record)
      allow(identifiers).to receive(:doi).and_return('doi')
      allow(identifiers).to receive(:pmid).and_return('123')
      allow(WebOfScience::Identifiers).to receive(:new).and_return(identifiers)
    end
    it 'sets doi' do
      expect(wos_src_rec.doi).to eq 'doi'
    end
    it 'sets pmid' do
      expect(wos_src_rec.pmid).to eq 123
    end
    it 'allows select' do
      wos_src_rec.save!
      expect(described_class.select(:doi).first).to be_an described_class
      expect(described_class.select(:pmid).first).to be_an described_class
    end
  end

  context 'source record validation' do
    it 'works' do
      expect(wos_src_rec.valid?).to be true
    end
    it 'allows select' do
      wos_src_rec.save!
      expect(described_class.select(:id).first).to be_an described_class
    end
  end

  context 'utility methods' do
    it 'has a Nokogiri::XML::Document' do
      expect(wos_src_rec.doc).to be_an Nokogiri::XML::Document
    end
    it 'has a WebOfScience::Record' do
      expect(wos_src_rec.record).to be_a WebOfScience::Record
    end
    it 'has an XML String' do
      expect(wos_src_rec.to_xml).to be_an String
    end
    it 'an XML String from the doc utility matches the source_data' do
      # TODO: use equivalent_xml
      expect(wos_src_rec.to_xml).to eq wos_src_rec.source_data
    end
  end
end
