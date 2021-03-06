# Various factories called below (via "create")
# @see spec/factories/publication.rb
# @see spec/factories/author.rb
# @see spec/factories/contribution.rb
describe SulBib::API, :vcr do
  let(:headers) { { 'HTTP_CAPKEY' => Settings.API_KEY, 'CONTENT_TYPE' => 'application/json' } }
  let(:publication) { create :publication }
  let(:author) { create :author }
  let(:sul_author_hash) { Hash[sul_author_id: author.id] }
  let(:contribution_count) { 2 }
  # let is lazy-evaluated: it is evaluated the first time it's method is invoked.
  # Use let! to force the method's invocation before each example.
  let!(:publication_with_contributions) do
    pub = create :publication_with_contributions, contributions_count: contribution_count
    # FactoryBot knows nothing about the Publication.pub_hash sync issue, so
    # it must be forced to update that data with the contributions.
    pub.pubhash_needs_update!
    pub.save # to update the pub.pub_hash
    pub
  end
  let(:base_data) do
    {
      featured: false,
      status: 'denied',
      visibility: 'private',
    }
  end
  let(:valid_data_for_post) { base_data.merge(sul_pub_id: publication.id) }
  let(:existing_contrib) { publication_with_contributions.contributions.first }
  let(:existing_contrib_ids) do
    {
      # author_hash is NOT merged here, because this data is concerned with an existing contribution.
      sul_author_id: existing_contrib.author.id,
      sul_pub_id: existing_contrib.publication.id
    }
  end
  let(:update_authorship_for_pub_with_contributions) { existing_contrib_ids.merge(base_data) }

  # For PATCH, the attribute params are optional, so only include those to be updated.

  # The shared examples require the calling example (or it's context)
  # to define a let(:http_request) that specifies the request
  # method path, json, headers
  # e.g.
  # let(:http_request) do
  #   post '/authorship', request_data.to_json, headers
  # end

  shared_examples 'it creates new contributions and publications' do
    let(:new_pub) { Publication.last }

    context 'with no other contributions' do
      let(:request_data) { valid_data_for_post.merge(author_hash) }
      it 'successfully creates one new contribution' do
        expect { http_request }.to change(Contribution, :count).by(1)
        expect(response.status).to eq(201)
      end
    end

    context 'with prior contributions' do
      let(:request_data) { base_data.merge(sul_pub_id: publication_with_contributions.id).merge(author_hash) }
      it 'successfully increases the publication\'s contribution records by one' do
        expect { http_request }.to change(publication_with_contributions.contributions, :count).by(1)
        expect(response).to have_http_status(:success)
        expect(publication_with_contributions.contributions.count).to eq(contribution_count + 1)
      end
      it 'creates one contribution record with matching attributes' do
        http_request
        query = Contribution.where(
          publication_id: publication_with_contributions.id,
          author_id: author.id
        )
        expect(query.count).to eq 1
        contribution = query.first
        expect(contribution.featured).to be false
        expect(contribution.status).to eq('denied')
        expect(contribution.visibility).to eq('private')
      end
      it 'adds the authorship entry to the pub_hash for the publication' do
        http_request
        authorship = publication_with_contributions.reload.pub_hash[:authorship]
        expect(authorship.any? { |a| a[:sul_author_id] == author.id }).to be true
      end
      it 'adds one authorship entry to response pub_hash' do
        # This specifically checks response data, whereas the prior spec checks data model.
        http_request
        # Expect a change in the number of contributions
        result_authorship = result['authorship']
        expect(result_authorship.length).to eq(contribution_count + 1)
        authorship_matches = result_authorship.select do |a|
          a['sul_author_id'] == author.id
        end
        expect(authorship_matches.length).to eq(1)
        expect(authorship_matches.first).to include('status' => 'denied', 'featured' => false, 'visibility' => 'private')
      end
    end # context 'with prior contributions'

    context 'for a new PubMed publication' do
      let(:request_data) { base_data.merge(pmid: '23684686').merge(author_hash) }
      before do
        http_request
        expect(response.body).to eq(new_pub.pub_hash.to_json)
      end

      it 'adds new publication' do
        expect(result['pmid']).to eq(request_data[:pmid])
        expect(result['authorship'].length).to eq 1
        contribution = Contribution.find_by(
          publication_id: new_pub.id,
          author_id: author.id)
        expect(contribution.featured).to eq(request_data[:featured])
        expect(contribution.status).to eq(request_data[:status])
        expect(contribution.visibility).to eq(request_data[:visibility])
      end

      it 'adds proper identifiers section' do
        expect(result['identifier']).to include(
          a_hash_including('type' => 'PMID', 'id' => request_data[:pmid], 'url' => "https://www.ncbi.nlm.nih.gov/pubmed/#{request_data[:pmid]}"),
          a_hash_including('type' => 'SULPubId', 'id' => new_pub.id.to_s, 'url' => "#{Settings.SULPUB_ID.PUB_URI}/#{new_pub.id}")
        )
      end
    end # context 'for a new PubMed publication'

    context 'for a new ScienceWire publication' do
      let(:request_data) { base_data.merge(sw_id: '10379039').merge(author_hash) }
      before do
        http_request
        expect(response.body).to eq(new_pub.pub_hash.to_json)
      end

      it 'adds new ScienceWire publication' do
        expect(result['sw_id']).to eq(request_data[:sw_id])
        expect(result['authorship'].length).to eq 1
        expect(result['authorship'][0]['sul_author_id']).to eq(author.id)
        contribution = Contribution.find_by(
          publication_id: new_pub.id,
          author_id: author.id)
        expect(contribution.featured).to eq(request_data[:featured])
        expect(contribution.status).to eq(request_data[:status])
        expect(contribution.visibility).to eq(request_data[:visibility])
      end

      it 'adds new ScienceWire publication with proper identifiers section' do
        expect(result['identifier']).to include(
          a_hash_including('type' => 'PublicationItemID', 'id' => request_data[:sw_id]),
          a_hash_including('type' => 'SULPubId', 'id' => new_pub.id.to_s, 'url' => "#{Settings.SULPUB_ID.PUB_URI}/#{new_pub.id}")
        )
      end
    end # context 'for a new ScienceWire publication'

    context 'for a new WoS publication' do
      # set Savon in and out of mock mode
      require 'savon/mock/spec_helper'
      include Savon::SpecHelper
      before(:all) { savon.mock!   }
      after(:all)  { savon.unmock! }

      let(:request_data) { base_data.merge(wos_uid: wos_record_uid).merge(author_hash) }

      let(:wos_record_uid) { 'WOS:A1972N549400003' }
      let(:wos_retrieve_by_id_response) { File.read('spec/fixtures/wos_client/wos_record_A1972N549400003_response.xml') }
      let(:wos_auth_response) { File.read('spec/fixtures/wos_client/authenticate.xml') }

      before do
        # Mock a WOS-API and Links-API interaction
        wos_client = WebOfScience::Client.new('secret')
        allow(WebOfScience).to receive(:client).and_return(wos_client)
        links_client = Clarivate::LinksClient.new
        wos_record_links = { wos_record_uid => { 'doi' => '10.5860/crl_33_05_413' } }
        allow(links_client).to receive(:links).with([wos_record_uid]).and_return(wos_record_links)
        allow(WebOfScience).to receive(:links_client).and_return(links_client)
        savon.expects(:authenticate).returns(wos_auth_response)
        savon.expects(:retrieve_by_id).with(message: :any).returns(wos_retrieve_by_id_response)
        # Issue an API call and check the response status
        http_request
        expect(response.body).to eq(new_pub.pub_hash.to_json)
      end

      it 'adds new WoS publication' do
        expect(result['wos_uid']).to eq(request_data[:wos_uid])
        expect(result['authorship'].length).to eq 1
        expect(result['authorship'][0]['sul_author_id']).to eq(author.id)
        contribution = Contribution.find_by(
          publication_id: new_pub.id,
          author_id: author.id)
        expect(contribution.featured).to eq(request_data[:featured])
        expect(contribution.status).to eq(request_data[:status])
        expect(contribution.visibility).to eq(request_data[:visibility])
      end

      it 'adds new WoS publication with proper identifiers section' do
        expect(result['identifier']).to include(
          a_hash_including('type' => 'WosUID', 'id' => request_data[:wos_uid]),
          a_hash_including('type' => 'SULPubId', 'id' => new_pub.id.to_s, 'url' => "#{Settings.SULPUB_ID.PUB_URI}/#{new_pub.id}")
        )
      end
    end # new WoS
  end

  shared_examples 'it updates an existing contribution' do
    # Convenience let! methods to store values for comparisons, using the
    # pub.pub_hash rather than the contrib_before object to be sure this
    # spec covers all the update ops that modify the pub.pub_hash.  Don't be
    # tempted to use the convenience methods used for all the other specs.
    # All of these must use `let!` so they execute before any http_request
    # in each example.
    let!(:contrib_before) do
      expect(existing_contrib.featured).to be true
      expect(existing_contrib.status).to eq 'approved'
      expect(existing_contrib.visibility).to eq 'public'
      existing_contrib
    end
    let!(:authorship_array) { contrib_before.publication.pub_hash[:authorship] }
    let!(:authorship_before) do
      authorship_matches = authorship_array.select do |a|
        a[:sul_author_id] == contrib_before.author.id ||
          a[:cap_profile_id] == contrib_before.author.cap_profile_id
      end
      expect(authorship_matches.length).to eq(1)
      authorship_matches.first
    end
    let(:request_data) { update_authorship_for_pub_with_contributions }

    it 'does not create a new contribution' do
      expect { http_request }.not_to change(Contribution, :count)
      expect(response).to have_http_status(:success)
    end

    it 'updates all contribution attributes' do
      http_request # defined in context, uses request_data
      existing_contrib.reload
      expect(request_data).to include(featured: !be_nil, status: be_present, visibility: be_present)
      expect(existing_contrib.featured).to be request_data[:featured]
      expect(existing_contrib.status).to eq request_data[:status]
      expect(existing_contrib.visibility).to eq request_data[:visibility]
    end

    it 'updates the pub hash authorship attributes' do
      http_request # defined in context, uses request_data
      # Expect no change in the number of contributions, only a
      # change in the attributes of the contribution updated.  In this
      # spec, the attributes must be checked in the response.
      result_authorship = result['authorship']
      expect(result_authorship.length).to eq(authorship_array.length)
      authorship_matches = result_authorship.select do |a|
        a['sul_author_id'] == request_data[:sul_author_id] ||
          a['cap_profile_id'] == request_data[:cap_profile_id]
      end
      expect(authorship_matches.length).to eq(1)
      authorship = authorship_matches.first
      expect(authorship).not_to eq(authorship_before)
      expect(request_data).to include(featured: !be_nil, status: be_present, visibility: be_present)
      expect(authorship).to include(
        'featured'   => request_data[:featured],
        'status'     => request_data[:status],
        'visibility' => request_data[:visibility]
      )
    end
  end # 'it updates an existing contribution'

  shared_examples 'it issues errors without author params' do
    let(:request_data) { valid_data_for_post }
    it 'returns 400 with an error message' do
      http_request
      expect(response.status).to eq 400
      expect(result['error']).to include('sul_author_id', 'cap_profile_id')
    end
  end

  shared_examples 'it issues errors when sul_author_id does not exist' do
    let(:sul_author_id) { '999999' }
    let(:request_data) { valid_data_for_post.merge(sul_author_id: sul_author_id) }

    it 'returns 404 when it fails to find a sul_author_id' do
      http_request
      expect(response.status).to eq 404
      expect(result['error']).to include('sul_author_id', sul_author_id)
    end
  end

  shared_examples 'it issues errors for cap_profile_id' do
    let(:cap_profile_id) { '999999' }
    let(:request_data) { valid_data_for_post.merge(cap_profile_id: cap_profile_id) }

    def check_response_error(code)
      expect(response.status).to eq code
      expect(result['error']).to include('cap_profile_id', cap_profile_id)
    end
    it 'returns 404 when it fails to find a cap_profile_id' do
      http_request
      check_response_error 404
    end
    it 'returns 404 when it cannot retrieve a cap_profile_id' do
      expect(Author).to receive(:fetch_from_cap_and_create).with(cap_profile_id)
      http_request
      check_response_error 404
    end
  end # shared_examples 'it issues errors for cap_profile_id'

  shared_examples 'it handles invalid authorship attributes' do
    let(:request_data) do
      update_authorship_for_pub_with_contributions.merge(visibility: 'invalid value')
    end
    it 'returns 406' do
      http_request
      expect(response.status).to eq 406
    end
  end

  # end of shared_examples
  # ---
  # POST

  context 'POST /authorship' do
    let(:http_request) { post '/authorship', request_data.to_json, headers }
    let(:result) { JSON.parse(response.body) } # invoke after http_request

    context 'success' do
      after(:example) { expect(response.status).to eq(201) }

      it_behaves_like 'it updates an existing contribution'

      context 'with sul_author_id' do
        let(:author_hash) { sul_author_hash }
        it_behaves_like 'it creates new contributions and publications' # TODO: modifies existing contributions.
      end

      context 'with cap_profile_id' do
        let(:author_hash) { Hash[cap_profile_id: author.cap_profile_id] }
        it_behaves_like 'it creates new contributions and publications' # TODO: modifies existing contributions.
      end

      context 'with allcaps or mixed case strings' do
        let(:request_data) { sul_author_hash.merge(sul_pub_id: publication_with_contributions.id, visibility: 'PRIVATE', status: 'New', featured: true) }
        it 'downcases appropriately' do
          expect { http_request }.not_to change { existing_contrib }
          contrib = publication_with_contributions.contributions.reload.last
          expect(contrib.status).to eq 'new'
          expect(contrib.visibility).to eq 'private'
        end
      end
    end # context 'success'

    context 'failure' do
      it_behaves_like 'it issues errors without author params'
      it_behaves_like 'it issues errors when sul_author_id does not exist'
      it_behaves_like 'it issues errors for cap_profile_id'
      it_behaves_like 'it handles invalid authorship attributes'

      it 'returns 500 error when publication contribution fails to save' do
        # Mock a publication in the valid request data so it fails to save.
        request_data = valid_data_for_post.merge(sul_author_hash)
        pub = Publication.find(request_data[:sul_pub_id])
        expect(pub).to receive(:save!).and_raise(ActiveRecord::RecordNotSaved.new(pub))
        expect(Publication).to receive(:find).with(pub.id.to_s).and_return(pub)
        post '/authorship', request_data.to_json, headers
        expect(response.status).to eq 500
      end

      context 'if there are publication errors' do
        let(:no_pub_params) { sul_author_hash.merge(base_data) }
        let(:id) { '0' }

        it 'returns 400 when publication parameters are missing' do
          post '/authorship', no_pub_params.to_json, headers
          expect(response.status).to eq 400
          expect(result['error']).to include('no valid publication identifier', 'sul_pub_id', 'pmid', 'sw_id', 'wos_uid')
        end
        context 'returns 404 with error message for invalid' do
          after { expect(response.status).to eq 404 }
          it 'sul_pub_id' do
            request_data = no_pub_params.merge(sul_pub_id: id)
            post '/authorship', request_data.to_json, headers
            expect(result['error']).to include(id, 'does not exist')
          end
          it 'pmid' do
            expect(Publication).to receive(:find_or_create_by_pmid)
            request_data = no_pub_params.merge(pmid: id)
            post '/authorship', request_data.to_json, headers
            expect(result['error']).to include(id, 'was not found')
          end
          it 'sw_id' do
            expect(Publication).to receive(:find_by).with(sciencewire_id: id)
            expect(SciencewireSourceRecord).to receive(:get_pub_by_sciencewire_id)
            request_data = no_pub_params.merge(sw_id: id)
            post '/authorship', request_data.to_json, headers
            expect(result['error']).to include(id, 'was not found')
          end
          it 'wos_uid' do
            expect(WebOfScience.harvester).to receive(:process_uids).with(Author, [id])
            request_data = no_pub_params.merge(wos_uid: id)
            post '/authorship', request_data.to_json, headers
            expect(result['error']).to include(id, 'was not found')
          end
        end
      end # context 'if there are publication errors'
    end # context 'failure'
  end # context 'POST /authorship'

  # ---
  # PATCH

  context 'PATCH /authorship' do
    let(:http_request) { patch '/authorship', request_data.to_json, headers }
    let(:result) { JSON.parse(response.body) } # invoke after http_request

    context 'success' do
      # The POST specs use either sul_author_id or cap_profile_id for creating
      # new contributions, because  it can create new authors for
      # cap_profile_id.  Testing the author parameters is not required for POST
      # requests that update a contribution (where the author already exists).
      # For all the PATCH specs, the contribution already exists, so testing
      # different author params is not important.
      after(:example) { expect(response.status).to eq(200) }

      it_behaves_like 'it updates an existing contribution'

      context 'to update featured contribution attribute' do
        let(:request_data) { existing_contrib_ids.merge(featured: false) }
        it 'sets featured only' do
          expect(request_data).not_to include(:status, :visibility)
          http_request # defined in context, uses request_data
          expect { existing_contrib.reload }.not_to change { [existing_contrib.visibility, existing_contrib.status] }
          expect(existing_contrib.featured).to be false
        end
      end

      context 'to update status contribution attribute' do
        let(:request_data) { existing_contrib_ids.merge(status: 'denied') }
        it 'sets status only' do
          expect(request_data).not_to include(:featured, :visibility)
          http_request # defined in context, uses request_data
          expect { existing_contrib.reload }.not_to change { [existing_contrib.visibility, existing_contrib.featured] }
          expect(existing_contrib.status).to eq 'denied'
        end
      end

      context 'to update visibility contribution attribute' do
        let(:request_data) { existing_contrib_ids.merge(visibility: 'private') }
        it 'sets visibility only' do
          expect(request_data).not_to include(:featured, :status)
          http_request # defined in context, uses request_data
          expect { existing_contrib.reload }.not_to change { [existing_contrib.status, existing_contrib.featured] }
          expect(existing_contrib.visibility).to eq 'private'
        end
      end

      context 'with allcaps or mixed case strings' do
        let(:request_data) { existing_contrib_ids.merge(visibility: 'PUBLIC', status: 'New') }
        it 'downcases appropriately' do
          http_request # defined in context, uses request_data
          expect { existing_contrib.reload }.not_to change { existing_contrib.featured }
          expect(existing_contrib.status).to eq 'new'
          expect(existing_contrib.visibility).to eq 'public'
        end
      end
    end # context 'success'

    context 'failure' do
      it_behaves_like 'it issues errors without author params'
      it_behaves_like 'it issues errors when sul_author_id does not exist'
      it_behaves_like 'it issues errors for cap_profile_id'
      it_behaves_like 'it handles invalid authorship attributes'

      context 'if there are contribution record errors' do
        # Use an existing contribution data for the request, to ensure it
        # gets past all the parameter checks, and mock the Contribution.where
        # method to ensure it returns missing or invalid data.
        let(:request_data) { update_authorship_for_pub_with_contributions }

        it 'returns 404 with error message for missing contributions' do
          # Although the request is valid and should find an existing
          # contribution, mock the response to ensure it's empty:
          expect(Contribution).to receive(:where).and_return([])
          http_request
          expect(response.status).to eq 404
          expect(result['error']).to include('no contributions', existing_contrib.author.id.to_s, existing_contrib.publication.id.to_s)
        end
        it 'returns 500 with error message for duplicate contributions' do
          # Although the request is valid and should find an existing
          # contribution, mock the response to ensure it has duplicates:
          expect(Contribution).to receive(:where).and_return(
            [existing_contrib, existing_contrib]
          )
          http_request
          expect(response.status).to eq 500
          expect(result['error']).to include('multiple contributions', existing_contrib.author.id.to_s, existing_contrib.publication.id.to_s)
        end
      end # context 'if there are contribution record errors'
    end # context 'failure'
  end # context 'PATCH /authorship'
end # end of the describe
