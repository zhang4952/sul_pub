describe WebOfScience::MapCitation do
  let(:wos_encoded_xml) { File.read('spec/fixtures/wos_client/wos_encoded_record.html') }
  let(:wos_record) { WebOfScience::Record.new(encoded_record: wos_encoded_xml) }

  let(:medline_encoded_xml) { File.read('spec/fixtures/wos_client/medline_encoded_record.html') }
  let(:medline_record) { WebOfScience::Record.new(encoded_record: medline_encoded_xml) }

  describe '#new' do
    it 'works with WOS records' do
      result = described_class.new(wos_record)
      expect(result).to be_an described_class
    end
    it 'raises ArgumentError with nil params' do
      expect { described_class.new }.to raise_error(ArgumentError)
    end
    it 'raises ArgumentError with anything other than WebOfScience::Record' do
      expect { described_class.new('could be xml') }.to raise_error(ArgumentError)
    end
  end

  shared_examples 'pub_hash' do
    it 'works' do
      expect(pub_hash).to be_an Hash
    end
  end

  shared_examples 'common_citation_data' do
    it 'has an year' do
      expect(pub_hash[:year]).not_to be_nil
    end
    it 'has an date' do
      expect(pub_hash[:date]).not_to be_nil
    end
    it 'has an pages' do
      expect(pub_hash[:pages]).not_to be_nil
    end
    it 'has an title' do
      expect(pub_hash[:title]).not_to be_nil
    end
    it 'has an journal' do
      expect(pub_hash[:journal]).not_to be_nil
    end
  end

  context 'WOS records' do
    let(:pub_hash_class) { described_class.new(wos_record) }
    let(:pub_hash) { pub_hash_class.pub_hash }

    it 'works with WOS records' do
      expect(pub_hash_class).to be_an described_class
    end
    it_behaves_like 'pub_hash'
    it_behaves_like 'common_citation_data'
    it 'trims the whitespace from the title' do
      expect(pub_hash[:title]).to eq 'LIBRARY MANAGEMENT - BEHAVIOR-BASED PERSONNEL SYSTEMS (BBPS) - FRAMEWORK FOR ANALYSIS - KEMPER,RE' # whitespace trimmed
    end
  end

  context 'MEDLINE records' do
    let(:pub_hash_class) { described_class.new(medline_record) }
    let(:pub_hash) { pub_hash_class.pub_hash }

    it 'works with MEDLINE records' do
      expect(pub_hash_class).to be_an described_class
    end
    it_behaves_like 'pub_hash'
    it_behaves_like 'common_citation_data'
    it 'trims the whitespace from the title' do
      expect(pub_hash[:title]).to eq 'Identifying druggable targets by protein microenvironments matching: application to transcription factors.' # whitespace trimmed
    end
  end
end
