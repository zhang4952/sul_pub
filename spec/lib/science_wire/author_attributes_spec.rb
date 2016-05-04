require 'spec_helper'

describe ScienceWire::AuthorAttributes do
  describe '#initialize' do
    subject { described_class.new(nil, nil, [], 0, [], nil) }
    it 'casts names and email to strings' do
      expect(subject.last_name).to be_an String
      expect(subject.first_name).to be_an String
      expect(subject.middle_name).to be_an String
      expect(subject.email).to be_an String
      expect(subject.institution).to be_an String
    end
  end
  describe '#first_name_initial' do
    context 'when not present' do
      subject { described_class.new(nil, nil, [], 0, [], nil) }
      it 'returns the first initial' do
        expect(subject.first_name_initial).to eq ''
      end
    end
    context 'when present' do
      subject { described_class.new(nil, 'Leland', [], 0, [], nil) }
      it 'returns the first initial' do
        expect(subject.first_name_initial).to eq 'L'
      end
    end
  end
  describe '#normalize_institution' do
    context 'when present with removed words at the beginning of the institution string' do
      subject { described_class.new(nil, nil, [], 0, [], 'The University of North Carolina') }
      it 'normalizes institution name' do
        expect(subject.institution).to eq 'north carolina'
      end
    end
    context 'when present with removed words throughout the institution string' do
      subject { described_class.new(nil, nil, [], 0, [], 'The Flinders University of South Australia') }
      it 'normalizes institution name' do
        expect(subject.institution).to eq 'flinders south australia'
      end
    end
    context 'when not present' do
      subject { described_class.new(nil, nil, [], 0, [], '') }
      it 'returns empty string' do
        expect(subject.institution).to eq ''
      end
    end
  end
end