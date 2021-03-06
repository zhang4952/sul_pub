describe ScienceWire::HarvestBroker do
  let(:author) { create(:author) }
  let(:author_name) do
    Agent::AuthorName.new(
      author.last_name,
      author.first_name,
      author.middle_name
    )
  end
  let(:feynman_name) { Agent::AuthorName.new('Feynman', 'Richard', 'P') }
  let(:alt_author) { create(:author_with_alternate_identities, alt_count: 3) }
  let(:alt_author_varying_institution) do
    auth = alt_author
    alt = auth.author_identities.first
    alt.institution = ''
    alt.save
    alt = auth.author_identities.second
    alt.institution = 'all'
    alt.save
    alt = auth.author_identities.last
    alt.institution = '*'
    alt.save
    auth
  end

  let(:contribution) { create(:contribution, author: author) }
  let(:harvester) { ScienceWireHarvester.new }
  subject { described_class.new(author, harvester) }
  describe '#initialize' do
    it 'default arguments' do
      expect(subject.alternate_name_query).to be false
    end
  end
  describe '#generate_ids' do
    before { allow(subject).to receive(:ids_for_author).and_return([1]) }
    it 'a set of ids generated from an author and alternate names' do
      allow(subject).to receive(:ids_for_alternate_names).and_return([1, 2])
      expect(subject.generate_ids).to eq [1, 2]
    end
    it 'removes any ids for existing author publications' do
      allow(subject).to receive(:ids_for_alternate_names).and_return([1, 2, 3])
      expect(subject).to receive(:author_pub_swids).and_return([3])
      expect(subject.generate_ids).to eq [1, 2]
    end
  end
  describe '#ids_for_author' do
    context 'with seed_list < 50' do
      it 'calls the dumb query' do
        expect(harvester).to receive(:increment_authors_with_limited_seed_data_count)
        expect(subject).to receive(:ids_from_dumb_query).and_return([1])
        expect(subject.send(:ids_for_author)).to eq [1]
      end
    end
    context 'with seed_list > 50' do
      it 'calls the smart query' do
        seed_list = (1..51).to_a
        author_attributes = ScienceWire::AuthorAttributes.new(
          author_name, author.email, seed_list, default_institution
        )
        expect(ScienceWire::AuthorAttributes).to receive(:new).and_return(author_attributes)
        expect(subject).to receive(:seed_list).twice.and_return(seed_list)
        expect(subject).to receive(:ids_from_smart_query).with(author_attributes).and_return([1])
        expect(subject.send(:ids_for_author)).to eq [1]
      end
    end
  end
  describe '#ids_for_alternate_names' do
    context 'when "alternate_name_query" is disabled' do
      subject { described_class.new(alt_author, harvester, alternate_name_query: false) }
      it 'returns an array' do
        expect(subject.send(:ids_for_alternate_names)).to eq []
      end
    end
    context 'when "alternate_name_query" is enabled' do
      subject { described_class.new(alt_author, harvester, alternate_name_query: true) }
      it 'returns an array of unique alternate name query ids' do
        expect(subject).to receive(:ids_from_dumb_query).exactly(3).times
          .and_return([1, 2], [2, 3], [3, 4])
        expect(subject.send(:ids_for_alternate_names)).to eq [1, 2, 3, 4]
      end
    end
    context 'when "alternate_name_query" is enabled and varying institution (blank, all, *)' do
      subject { described_class.new(alt_author_varying_institution, harvester, alternate_name_query: true) }
      it 'returns an empty array' do
        expect(subject).not_to receive(:ids_from_dumb_query)
        expect(subject.send(:ids_for_alternate_names)).to eq []
      end
    end
  end
  describe '#ids_from_dumb_query' do
    let(:client_instance) { instance_double(ScienceWireClient) }
    before do
      allow(ScienceWireClient).to receive(:new).and_return(client_instance)
    end
    it 'gets ids from ScienceWireClient#query_sciencewire_by_author_name' do
      expect(client_instance).to receive(:query_sciencewire_by_author_name)
        .and_return([1, 2, 3])
      expect(subject.ids_from_dumb_query(feynman_name))
        .to eq [1, 2, 3]
    end
  end
  describe '#ids_from_smart_query', :vcr do
    let(:client_instance) { instance_double(ScienceWireClient) }
    before do
      allow(ScienceWireClient).to receive(:new).and_return(client_instance)
    end
    it 'gets ids from ScienceWireClient#get_sciencewire_id_suggestions' do
      author_attributes = ScienceWire::AuthorAttributes.new(
        feynman_name, 'rf@caltech.edu', []
      )
      expect(client_instance).to receive(:get_sciencewire_id_suggestions)
        .with(author_attributes)
        .and_return([1, 2, 3])
      expect(
        subject.ids_from_smart_query(author_attributes)
      ).to eq [1, 2, 3]
    end
  end

  describe 'seed_list' do
    it 'returns an Array<Integer>' do
      expect(author).to receive(:approved_sciencewire_ids).and_return([1])
      seeds = subject.send(:seed_list)
      expect(seeds).to be_an Array
      expect(seeds).not_to be_empty
      expect(seeds.first).to be_an Integer
    end
  end

  describe 'author_name' do
    it 'returns a Agent::AuthorName' do
      name = subject.send(:author_name, author)
      expect(name).to be_an Agent::AuthorName
    end
  end
end
