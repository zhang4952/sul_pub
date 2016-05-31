require 'spec_helper'

describe SulBib::API, :vcr do
  let(:publication) { FactoryGirl.create :publication }
  let!(:publication_with_contributions) { create :publication_with_contributions, contributions_count: 2 }
  let(:publication_list) { create_list(:contribution, 15, visibility: 'public', status: 'approved') }
  let(:author) { FactoryGirl.create :author }
  let(:author_with_sw_pubs) { create :author_with_sw_pubs }
  let(:headers) { { 'HTTP_CAPKEY' => Settings.API_KEY, 'CONTENT_TYPE' => 'application/json' } }
  let(:valid_json_for_post) do
    {
      type: 'book',
      title: 'some title',
      year: 1938,
      issn: '32242424',
      pages: '34-56',
      author: [{
        name: 'jackson joe'
      }],
      authorship: [{
        cap_profile_id: author.cap_profile_id,
        sul_author_id: author.id,
        status: 'denied',
        visibility: 'public',
        featured: true
      }]
    }.to_json
  end

  let(:invalid_json_for_post) do
    pub = JSON.parse(valid_json_for_post.dup)
    pub.delete 'authorship'
    pub.to_json
  end

  let(:json_with_new_author) do
    pub = JSON.parse(valid_json_for_post.dup)
    pub['author'] = [{
      name: 'henry lowe'
    }]
    pub['authorship'] = [{
      cap_profile_id: '3810',
      status: 'denied',
      visibility: 'public',
      featured: true
    }]
    pub.to_json
  end

  let(:json_with_isbn) do
    {
      abstract: '',
      abstract_restricted: '',
      allAuthors: 'author A, author B',
      author: [
        {firstname: 'John ', lastname: 'Doe', middlename: '', name: 'Doe  John ', role: 'author'},
        {firstname: 'Raj', lastname: 'Kathopalli', middlename: '', name: 'Kathopalli  Raj', role: 'author'}
      ],
      authorship: [
        {cap_profile_id: author.cap_profile_id, featured: true, status: 'APPROVED', visibility: 'PUBLIC'}
      ],
      booktitle: 'TEST Book I',
      edition: '2',
      etal: true,
      identifier: [
        {type: 'isbn', id: '1177188188181'},
        {type: 'doi', url: '18819910019'}
      ],
      last_updated: '2013-08-10T21:03Z',
      provenance: 'CAP',
      publisher: 'Publisher',
      series: {number: '919', title: 'Series 1', volume: '1'},
      type: 'book',
      year: '2010'
    }.to_json
  end

  let(:json_with_isbn_changed_doi) do
    pub = JSON.parse(json_with_isbn.dup)
    pub['identifier'] = [
      {type: 'isbn', id: '1177188188181'},
      {type: 'doi', url: '18819910019-updated' },
      {type: 'SULPubId', id: '164', url: Settings.SULPUB_ID.PUB_URI + '/164' }
    ]
    pub.to_json
  end

  let(:json_with_isbn_deleted_doi) do
    pub = JSON.parse(json_with_isbn_changed_doi.dup)
    pub['identifier'] = [
      {type: 'isbn', id: '1177188188181'},
      {type: 'SULPubId', id: '164', url: Settings.SULPUB_ID.PUB_URI + '/164' }
    ]
    pub.to_json
  end

  let(:json_with_pubmedid) do
    pub = JSON.parse(json_with_isbn.dup)
    pub['identifier'] = [
      {type: 'isbn', id: '1177188188181'},
      {type: 'doi', url: '18819910019'},
      {type: 'pmid', id: '999999999'},
    ]
    pub.to_json
  end

  let(:article_with_authorship_without_authors) do
    {
      allAuthors: '',
      author: [{}],
      authorship: [{
        cap_profile_id: author.cap_profile_id,
        featured: false,
        status: 'APPROVED',
        visibility: 'PUBLIC'
      }],
      etal: false,
      journal: {},
      last_updated: '2015-11-23T15:15Z',
      provenance: 'CAP',
      publisher: '',
      type: 'article',
      title: 'Test Article2 11-23-2015',
      year: '2015'
    }.to_json
  end

  # ---------------------------------------------------------------------
  # POST

  def post_valid_json
    post '/publications', valid_json_for_post, headers
    expect(response.status).to eq(201)
  end

  def validate_authorship(pub_hash, submission)
    expect(pub_hash[:author]).to eq(submission['author'])
    expect(pub_hash[:authorship].length).to eq(submission['authorship'].length)
    matching_fields = %w(visibility status featured cap_profile_id)
    pub_hash[:authorship].each_with_index do |pub_authorship, index|
      sub_authorship = submission['authorship'][index]
      expect(sub_authorship).not_to be_nil
      expect(sub_authorship).not_to be_empty
      expect(pub_authorship).not_to be_nil
      expect(pub_authorship).not_to be_empty
      matching_fields.each do |field|
        pub_field = pub_authorship[field.to_sym]
        sub_field = sub_authorship[field]
        expect(sub_field).not_to be_nil
        expect(pub_field).not_to be_nil
        expect(pub_field).to eq(sub_field)
      end
    end
  end

  describe 'POST /publications' do
    context 'when valid post' do
      it 'responds with 201' do
        post_valid_json
      end

      it 'returns bibjson from the pub_hash for the new publication' do
        post_valid_json
        expect(response.body).to eq(Publication.last.pub_hash.to_json)
      end

      it 'creates a new contributions record in the db' do
        post_valid_json
        expect(Contribution.where(publication_id: Publication.last.id, author_id: author.id).first.status).to eq('denied')
      end

      it 'increases number of contribution records by one' do
        expect{ post_valid_json }.to change(Contribution, :count).by(1)
      end

      it 'increases number of publication records by one' do
        expect{ post_valid_json }.to change(Publication, :count).by(1)
      end

      it 'increases number of user submitted source records by one' do
        expect{ post_valid_json }.to change(UserSubmittedSourceRecord, :count).by(1)
      end

      it 'creates an appropriate publication record from the posted bibjson' do
        post_valid_json
        pub = Publication.last
        submission = JSON.parse(valid_json_for_post)
        expect(pub.title).to eq(submission['title'])
        expect(pub.year).to eq(submission['year'])
        expect(pub.pages).to eq(submission['pages'].sub('-', '–')) # em-dash
        expect(pub.issn).to eq(submission['issn'])
      end

      it 'creates a matching pub_hash in the publication record from the posted bibjson' do
        post_valid_json
        pub_hash = Publication.last.reload.pub_hash
        submission = JSON.parse(valid_json_for_post)
        validate_authorship(pub_hash, submission)
      end

      it 'handles missing author using authorship from the posted bibjson' do
        post '/publications', article_with_authorship_without_authors, headers
        expect(response.status).to eq(201)
        pub_hash = Publication.last.reload.pub_hash
        submission = JSON.parse(article_with_authorship_without_authors)
        validate_authorship(pub_hash, submission)
      end

      it ' creates a pub with matching authorship info in hash and contributions table' do
        post_valid_json
        pub = Publication.last
        submission = JSON.parse(valid_json_for_post)
        contrib = Contribution.where(publication_id: pub.id, author_id: author.id).first
        # TODO: evaluate whether authorship array should result in one or more contributions?
        expect(contrib.visibility).to eq(submission['authorship'][0]['visibility'])
        expect(contrib.status).to eq(submission['authorship'][0]['status'])
        expect(contrib.featured).to eq(submission['authorship'][0]['featured'])
        expect(contrib.cap_profile_id).to eq(submission['authorship'][0]['cap_profile_id'])
      end

      it 'does not duplicate SULPubIds' do
        json_with_sul_pub_id = { type: 'book', identifier: [{ type: 'SULPubId', id: 'n', url: 'm' }], authorship: [{ sul_author_id: author.id, status: 'denied', visibility: 'public', featured: true }] }.to_json
        post '/publications', json_with_sul_pub_id, headers
        expect(response.status).to eq(201)
        parsed_outgoing_json = JSON.parse(response.body)
        expect(parsed_outgoing_json['identifier'].count { |x| x['type'] == 'SULPubId' }).to eq(1)
        expect(parsed_outgoing_json['identifier'][0]['id']).not_to eq('n')
      end

      it 'creates a pub with with isbn' do
        post '/publications', json_with_isbn, headers
        expect(response.status).to eq(201)
        pub = Publication.last.reload
        # TODO: use the submission data to validate some of the identifier fields
        # submission = JSON.parse(json_with_isbn)
        parsed_outgoing_json = JSON.parse(response.body)
        expect(parsed_outgoing_json['identifier']).to include('id' => '1177188188181', 'type' => 'isbn')
        expect(parsed_outgoing_json['identifier']).to include('type' => 'doi', 'url' => '18819910019')
        expect(parsed_outgoing_json['identifier']).to include('type' => 'SULPubId', 'url' => "#{Settings.SULPUB_ID.PUB_URI}/#{pub.id}", 'id' => pub.id.to_s)
        expect(parsed_outgoing_json['identifier'].size).to eq(3)
        expect(pub.publication_identifiers.size).to eq(2)
        expect(pub.publication_identifiers.map(&:identifier_type)).to include('doi', 'isbn')
        expect(response.body).to eq(pub.pub_hash.to_json)
      end

      it 'creates a pub with with pmid' do
        post '/publications', json_with_pubmedid, headers
        expect(response.status).to eq(201)
        pub = Publication.last.reload
        parsed_outgoing_json = JSON.parse(response.body)
        expect(parsed_outgoing_json['identifier']).to include('id' => '999999999', 'type' => 'pmid')
        expect(pub.publication_identifiers.map(&:identifier_type)).to include('pmid')
        expect(response.body).to eq(pub.pub_hash.to_json)
      end
    end # end of the context

    context 'when valid post' do
      it ' returns 302 for duplicate pub' do
        post '/publications', valid_json_for_post, headers
        expect(response.status).to eq(201)
        post '/publications', valid_json_for_post, headers
        expect(response.status).to eq(302)
      end

      it ' returns 406 - Not Acceptable for bibjson without an authorship entry' do
        post '/publications', invalid_json_for_post, headers
        expect(response.status).to eq(406)
      end

      it 'creates an Author when a new cap_profile_id is passed in' do
        skip 'Administrative Systems firewall only allows IP-based requests'
        post '/publications', json_with_new_author, headers
        expect(response.status).to eq(201)
        auth = Author.where(cap_profile_id: '3810').first
        expect(auth.cap_last_name).to eq('Lowe')
      end
    end
  end # end of the describe

  # ---------------------------------------------------------------------
  # PUT

  describe 'PUT /publications/:id' do
    it 'does not duplicate SULPubIDs' do
      json_with_sul_pub_id = {
        type: 'book',
        identifier: [{
          type: 'SULPubId',
          id: 'n',
          url: 'm'
        }],
        authorship: [{
          sul_author_id: author.id,
          status: 'denied',
          visibility: 'public',
          featured: true
        }]
      }.to_json
      put "/publications/#{publication.id}", json_with_sul_pub_id, headers
      expect(response.status).to eq(200)
      parsed_outgoing_json = JSON.parse(response.body)
      expect(parsed_outgoing_json['identifier'].count { |x| x['type'] == 'SULPubId' }).to eq(1)
      expect(parsed_outgoing_json['identifier'][0]['id']).not_to eq('n')
    end

    it 'updates an existing pub ' do
      post '/publications', json_with_isbn, headers
      id = Publication.last.id
      put "/publications/#{id}", json_with_isbn_changed_doi, headers
      parsed_outgoing_json = JSON.parse(response.body)
      expect(parsed_outgoing_json['identifier'].size).to eq(3)
      expect(parsed_outgoing_json['identifier']).to include('type' => 'isbn', 'id' => '1177188188181')
      expect(parsed_outgoing_json['identifier']).to include('type' => 'doi', 'url' => '18819910019-updated')
      expect(parsed_outgoing_json['identifier']).to include('type' => 'SULPubId', 'id' => id.to_s, 'url' => "#{Settings.SULPUB_ID.PUB_URI}/#{id}")
    end

    it 'deletes an identifier from the db if it is not in the incoming json' do
      post '/publications', json_with_isbn, headers
      id = Publication.last.id
      put "/publications/#{id}", json_with_isbn_deleted_doi, headers
      parsed_outgoing_json = JSON.parse(response.body)
      expect(parsed_outgoing_json['identifier'].size).to eq(2)
      expect(parsed_outgoing_json['identifier']).to include('type' => 'isbn', 'id' => '1177188188181')
      expect(parsed_outgoing_json['identifier']).to include('type' => 'SULPubId', 'url' => "#{Settings.SULPUB_ID.PUB_URI}/#{id}", 'id' => id.to_s)
    end
  end

  # ---------------------------------------------------------------------
  # GET

  describe 'GET /publications/:id' do
    it ' returns 200 for valid call ' do
      get "/publications/#{publication.id}",
          { format: 'json' },
          headers
      expect(response.status).to eq(200)
    end
    it 'returns a publication bibjson doc by id' do
      publication
      get "/publications/#{publication.id}",
          { format: 'json' },
          'HTTP_CAPKEY' => Settings.API_KEY
      expect(response.body).to eq(publication.pub_hash.to_json)
    end

    it 'returns a pub with valid bibjson for sw harvested records' do
      auth = author_with_sw_pubs
      auth.contributions.destroy_all # wipe the slate clean
      ScienceWireHarvester.new.harvest_pubs_for_author_ids([auth.id])
      new_pub = Publication.last
      get "/publications/#{new_pub.id}",
          { format: 'json' },
          headers
      expect(response.status).to eq(200)
      expect(response.body).to eq(new_pub.pub_hash.to_json)
      result = JSON.parse(response.body)
      expect(result['provenance']).to eq('sciencewire')
      expect(result['type']).to eq('article')
    end

    it 'returns only those pubs changed since specified date'
    it 'returns only those pubs with contributions for the given author'
    it 'returns only pubs with a cap active profile'

    context "when pub id doesn't exist" do
      it 'returns not found code' do
        get '/publications/88888888888',
            { format: 'json' },
            headers
        expect(response.status).to eq(404)
      end
    end
  end # end of the describe

  describe 'GET /publications' do
    context 'with no params specified' do
      it 'returns first page' do
        get '/publications/',
            { format: 'json' },
            headers
        result = JSON.parse(response.body)
        expect(result['metadata']['page']).to eq(1)
        expect(JSON.parse(response.body)['records']).to be
      end
    end # end of context

    context 'when there are 150 records' do
      it "raises an error if a capkey isn't provided" do
        publication_list
        get '/publications?page=1&per=7',
            format: 'json'
        expect(response.status).to eq(401)
      end

      it 'returns a one page collection of 100 bibjson records when no paging is specified' do
        publication_list
        get '/publications?page=1&per=7',
            { format: 'json' },
            headers
        expect(response.status).to eq(200)
        expect(response.headers['Content-Type']).to be =~ %r{application/json}

        result = JSON.parse(response.body)

        expect(result['metadata']['records']).to eq('7')
        expect(result['metadata']['page']).to eq(1)
        expect(result['records'][2]['author']).to be
      end

      it 'filters by active authors' do
        publication_list
        get '/publications?page=1&per=1&capActive=true',
            { format: 'json' },
            headers
        expect(response.status).to eq(200)
        result = JSON.parse(response.body)
        expect(result['metadata']['records']).to eq('1')
        expect(result['metadata']['page']).to eq(1)
      end

      it 'paginates by active authors' do
        publication_list
        get '/publications?page=2&per=1&capActive=true',
            { format: 'json' },
            headers
        expect(response.status).to eq(200)
        result = JSON.parse(response.body)
        expect(result['metadata']['records']).to eq('1')
        expect(result['metadata']['page']).to eq(2)
      end
    end # end of context
  end # end of the describe
end