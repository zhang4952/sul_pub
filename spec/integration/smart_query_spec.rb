require 'spec_helper'

describe 'Smart query', 'data-integration': true do
  let(:client) do
    ScienceWire::Client.new(
      license_id: Settings.SCIENCEWIRE.LICENSE_ID,
      host: Settings.SCIENCEWIRE.HOST
    )
  end
  context 'with email address only' do
    context 'using Darren Hardy' do
      it 'returns suggestions' do
        known_confirmed_publications = ['64367696']
        suggestions = client.id_suggestions(
          ScienceWire::AuthorAttributes.new(
            'Hardy', 'Darren', '', 'darren.hardy@stanford.edu', ''
          )
        )
        expect(suggestions.count).to be >= 1 # only 1 is correct
        expect(suggestions).to include(*known_confirmed_publications)
      end
      it 'returns suggestions' do
        known_confirmed_publications = ['64367696']
        suggestions = client.id_suggestions(
          ScienceWire::AuthorAttributes.new(
            'Hardy', 'Darren', '', 'drh@stanford.edu', ''
          )
        )
        expect(suggestions.count).to be >= 1 # only 1 in correct
        expect(suggestions).to include(*known_confirmed_publications)
      end
      it 'returns suggestions' do
        known_confirmed_publications = ['61063453', '64367696', '67380595']
        suggestions = client.id_suggestions(
          ScienceWire::AuthorAttributes.new(
            'Hardy', 'Darren', '', 'dhardy@bren.ucsb.edu', ''
          )
        )
        expect(suggestions.count).to be >= 3 # only 3 are correct
        expect(suggestions).to include(*known_confirmed_publications)
      end
    end
    context 'using Jack Reed' do
      it 'returns suggestions' do
        known_confirmed_publications = ['60931052']
        suggestions = client.id_suggestions(
          ScienceWire::AuthorAttributes.new(
            'Reed', 'P', '', 'preed2@gsu.edu', ''
          )
        )
        expect(suggestions.count).to be >= 33
        expect(suggestions).to include(*known_confirmed_publications)
      end
      it 'returns suggestions' do
        known_confirmed_publications = ['69178421']
        suggestions = client.id_suggestions(
          ScienceWire::AuthorAttributes.new(
            'Reed', 'J', '', 'preed2@gsu.edu', ''
          )
        )
        expect(suggestions.count).to be >= 68
        expect(suggestions).to include(*known_confirmed_publications)
      end
    end
  end
end