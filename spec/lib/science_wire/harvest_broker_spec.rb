require 'spec_helper'

describe ScienceWire::HarvestBroker do
  let(:author) { create(:author) }
  let(:alt_author) { create(:author_with_alternate_identities, alt_count: 3) }
  let(:contribution) { create(:contribution, author: author) }
  let(:harvester) { ScienceWireHarvester.new }
  subject { described_class.new(author, harvester) }
  describe '#initialize' do
    it 'default arguments' do
      expect(subject.alternate_name_query).to be false
    end
  end
  describe '#generate_ids' do
    it 'a set of ids generated from an author and alternate names' do
      expect(subject).to receive(:ids_for_author).and_return([1])
      expect(subject).to receive(:ids_for_alternate_names).and_return([1, 2])
      expect(subject.generate_ids).to eq [1, 2]
    end
  end
  describe '#ids_for_author' do
    context 'with seed_list < 50' do
      it 'calls the dumb query' do
        expect(harvester).to receive(:increment_authors_with_limited_seed_data_count)
        expect(subject).to receive(:ids_from_dumb_query)
          .with('Alice', 'Jim', 'Edler').and_return([1])
        expect(subject.ids_for_author).to eq [1]
      end
    end
    context 'with seed_list > 50' do
      it 'calls the smart query' do
        expect(subject).to receive(:seed_list).twice
          .and_return((1..51).to_a)
        expect(subject).to receive(:ids_from_smart_query)
          .with('Edler', 'Alice', 'Jim', 'alice.edler@stanford.edu', duck_type(:[]))
          .and_return([1])
        expect(subject.ids_for_author).to eq [1]
      end
    end
  end
  describe '#ids_for_alternate_names' do
    context 'when alternate_name_query is disabled' do
      subject { described_class.new(alt_author, harvester, alternate_name_query: false) }
      it 'returns an array' do
        expect(subject.ids_for_alternate_names).to be_an Array
        expect(subject.ids_for_alternate_names).to be_empty
      end
    end
    context 'when alternate_name_query is enabled' do
      subject { described_class.new(alt_author, harvester, alternate_name_query: true) }
      it 'returns an array of unique alternate name query ids' do
        expect(subject).to receive(:ids_from_dumb_query).exactly(3).times
          .and_return([1, 2], [2, 3], [3, 4])
        expect(subject.ids_for_alternate_names).to eq [1, 2, 3, 4]
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
      expect(subject.ids_from_dumb_query('Richard', 'P', 'Feynman'))
        .to eq [1, 2, 3]
    end
  end
  describe '#ids_from_smart_query', :vcr do
    let(:client_instance) { instance_double(ScienceWireClient) }
    before do
      allow(ScienceWireClient).to receive(:new).and_return(client_instance)
    end
    it 'gets ids from ScienceWireClient#get_sciencewire_id_suggestions' do
      expect(client_instance).to receive(:get_sciencewire_id_suggestions)
        .and_return([1, 2, 3])
      expect(
        subject.ids_from_smart_query(
          'Feynman', 'Richard', 'P', 'rf@caltech.edu', ''
        )).to eq [1, 2, 3]
    end
  end
end