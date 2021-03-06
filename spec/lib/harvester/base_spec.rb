describe Harvester::Base do
  let(:authors) { FactoryBot.create_list(:author, 5, cap_import_enabled: true) }
  let(:subclass) { Class.new(described_class) }
  let(:instance) { subclass.new }
  let(:null_logger) { Logger.new('/dev/null') }

  describe '#harvest_all' do
    it 'chunks calls to harvest based on batch_size' do
      expect { authors }.to change { Author.count }.by(5)
      expect(instance).to receive(:batch_size).exactly(4).times.and_return(2)
      expect(instance).to receive(:logger).exactly(3).times.and_return(null_logger)
      expect(instance).to receive(:harvest).exactly(3).times
      instance.harvest_all
    end
  end

  describe '#harvest' do
    it 'throws exception from base class' do
      expect { instance.harvest([]) }.to raise_error(RuntimeError)
    end
  end
end
