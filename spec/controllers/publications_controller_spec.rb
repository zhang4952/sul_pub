require 'spec_helper'

describe PublicationsController do
  describe 'GET index' do
    context 'with a capProfileId that is not tied to an Author' do
      it 'returns a 404' do
        expect(controller).to receive(:check_authorization).and_return(true)
        get :index, capProfileId: 'nada'
        expect(response.status).to eq 404
        expect(response.body).to eq 'No such author'
      end
    end
  end
end