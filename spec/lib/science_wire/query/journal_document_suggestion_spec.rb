require 'spec_helper'

describe ScienceWire::Query::JournalDocumentSuggestion do
  include SuggestionQueries
  subject { described_class.new(author_attributes) }
  let(:author_name) { ScienceWire::AuthorName.new('Doe', 'John', 'S') }
  let(:author_attributes) do
    ScienceWire::AuthorAttributes.new(
      author_name, 'johnsdoe@example.com', [532_237]
    )
  end
  it 'returns a suggestion query with journal document' do
    expect(subject.generate).to be_equivalent_to(journal_doc_email_and_seed)
  end
end
