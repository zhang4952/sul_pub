describe WebOfScience::ProcessRecords, :vcr do
  let(:author) do
    # public data from
    # - https://stanfordwho.stanford.edu
    # - https://med.stanford.edu/profiles/russ-altman
    author = FactoryBot.create(:author,
                                 preferred_first_name: 'Russ',
                                 preferred_last_name: 'Altman',
                                 preferred_middle_name: 'Biagio',
                                 email: 'Russ.Altman@stanford.edu',
                                 cap_import_enabled: true)
    # create some `author.alternative_identities`
    FactoryBot.create(:author_identity,
                       author: author,
                       first_name: 'R',
                       middle_name: 'B',
                       last_name: 'Altman',
                       email: nil,
                       institution: 'Stanford University')
    FactoryBot.create(:author_identity,
                       author: author,
                       first_name: 'Russ',
                       middle_name: nil,
                       last_name: 'Altman',
                       email: nil,
                       institution: nil)
    author
  end

  let(:links_client) { Clarivate::LinksClient.new }

  before do
    null_logger = Logger.new('/dev/null')
    allow(WebOfScience).to receive(:logger).and_return(null_logger)
    allow(processor).to receive(:links_client).and_return(links_client)
  end

  shared_examples '#execute' do
    # ---
    # Happy paths

    it 'returns an Array' do
      expect(processor.execute).to be_an Array
    end
    it 'returns Array<String> with WosUIDs on success' do
      result = processor.execute
      uid_success = result & records.uids
      expect(uid_success).not_to be_empty
    end
    it 'creates new WebOfScienceSourceRecords' do
      expect { processor.execute }.to change { WebOfScienceSourceRecord.count }
    end

    it 'creates new Publications' do
      expect { processor.execute }.to change { Publication.count }
    end
    it 'creates Publications with WOS attributes' do
      processor.execute
      records.uids.each do |uid|
        pub = Publication.find_by(wos_uid: uid)
        expect(pub).not_to be_nil
        expect(pub.pub_hash[:provenance]).to eq Settings.wos_source
      end
    end

    it 'creates new PublicationIdentifiers' do
      expect { processor.execute }.to change { PublicationIdentifier.count }
    end

    it 'creates new Contributions' do
      expect { processor.execute }.to change { Contribution.count }
    end
    it 'creates new contribution in the pub_hash[:authorship]' do
      processor.execute
      records.each do |rec|
        pub = Publication.find_by(wos_uid: rec.uid)
        expect(pub.pub_hash).to include(:authorship)
      end
    end

    # ---
    # Unhappy paths

    it 'raises ArgumentError for author' do
      expect { described_class.new('author', records) }.to raise_error(ArgumentError)
    end
    it 'raises ArgumentError for records' do
      expect { described_class.new(author, []) }.to raise_error(ArgumentError)
    end

    context 'save_wos_records fails' do
      before do
        allow(processor).to receive(:save_wos_records).and_raise(RuntimeError)
      end

      it 'does not create new WebOfScienceSourceRecords' do
        expect { processor.execute }.not_to change { WebOfScienceSourceRecord.count }
      end
      it 'logs errors' do
        expect(NotificationManager).to receive(:error)
        processor.execute
      end
      it 'returns empty Array' do
        expect(processor.execute).to be_an Array
        expect(processor.execute).to be_empty
      end
    end

    context 'create_publication fails' do
      before do
        allow(Publication).to receive(:new).and_raise(ActiveRecord::RecordInvalid)
      end

      it 'does not create new Publications' do
        expect { processor.execute }.not_to change { Publication.count }
      end
      it 'does not create new Contributions' do
        expect { processor.execute }.not_to change { Contribution.count }
      end
      it 'logs errors' do
        expect(NotificationManager).to receive(:error)
        processor.execute
      end
      it 'returns empty Array' do
        expect(processor.execute).to be_an Array
        expect(processor.execute).to be_empty
      end
    end
  end

  # ---
  # MESH headings - integration specs
  # Note: not all PubMed/MEDLINE records contain MESH headings, so the
  # spec example records were chosen to contain or fetch MESH headings

  shared_examples 'pubs_with_pmid_have_mesh_headings' do
    # Note: the spec example records have MESH headings
    it 'creates publication.pub_hash with MESH headings' do
      processor.execute
      records.select(&:pmid).each do |rec|
        pub = Publication.find_by(wos_uid: rec.uid)
        expect(pub.pub_hash).to include(:mesh_headings)
      end
    end
  end

  context 'with MEDLINE records' do
    subject(:processor) { described_class.new(author, records) }

    # Note: "MEDLINE:26776186" has a PMID and MESH headings
    let(:medline_xml) { File.read('spec/fixtures/wos_client/medline_record_26776186.xml') }
    let(:records_xml) { "<records>#{medline_xml}</records>" }
    let(:records) { WebOfScience::Records.new(records: records_xml) }

    # Note: medline records are not submitted to the links-API

    it_behaves_like '#execute'
    it_behaves_like 'pubs_with_pmid_have_mesh_headings'
  end

  context 'with WOS records' do
    subject(:processor) { described_class.new(author, records) }

    # Note: "WOS:000288663100014" has a PMID and it gets MESH headings from PubMed
    let(:wos_record_uid) { 'WOS:000288663100014' }
    let(:wos_record_xml) { File.read('spec/fixtures/wos_client/wos_record_000288663100014.xml') }
    let(:wos_records_xml) { "<records>#{wos_record_xml}</records>" }
    let(:wos_records_links) do
      { 'WOS:000288663100014' => { 'pmid' => '21253920', 'doi' => '10.1007/s12630-011-9462-1' } }
    end

    let(:records) { WebOfScience::Records.new(records: wos_records_xml) }

    before do
      allow(links_client).to receive(:links).with([wos_record_uid]).and_return(wos_records_links)
    end

    it_behaves_like '#execute'
    it_behaves_like 'pubs_with_pmid_have_mesh_headings'

    context 'WOS links fail' do
      # only WOS records use the links service
      # any failure to add links data is not catastrophic - just log it
      before do
        allow(links_client).to receive(:links).and_raise(RuntimeError)
      end

      it 'continues to create new Publications' do
        expect { processor.execute }.to change { Publication.count }
      end
      it 'logs errors' do
        expect(NotificationManager).to receive(:error)
        processor.execute
      end
    end

    context 'WOS links - identifier update fails' do
      # only WOS records use the links service
      # any failure to add links data is not catastrophic - just log it
      before do
        identifiers = WebOfScience::Identifiers.new(records.first)
        allow(identifiers).to receive(:update).and_raise(RuntimeError)
        allow(WebOfScience::Identifiers).to receive(:new).and_return(identifiers)
      end

      it 'continues to create new Publications' do
        expect { processor.execute }.to change { Publication.count }
      end
      it 'logs errors' do
        expect(NotificationManager).to receive(:error)
        processor.execute
      end
    end
  end

  context 'with records from excluded databases' do
    subject(:processor) { described_class.new(author, records) }

    let(:other_record_xml) do
      xml = File.read('spec/fixtures/wos_client/wos_record_000288663100014.xml')
      xml.gsub('WOS', 'EXCLUDED')
    end
    let(:other_records_xml) { "<records>#{other_record_xml}</records>" }
    let(:other_records) { WebOfScience::Records.new(records: other_records_xml) }

    let(:records) { other_records }

    it 'does not create new WebOfScienceSourceRecords' do
      expect { processor.execute }.not_to change { WebOfScienceSourceRecord.count }
    end
    it 'filters out excluded records' do
      expect(processor.send(:filter_databases)).to be_empty
    end
  end
end
