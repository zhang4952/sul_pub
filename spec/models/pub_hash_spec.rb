require 'spec_helper'

describe PubHash do
  let(:conference_pub_in_journal_hash) do
    { title: 'My test title',
      type: 'paper-conference',
      articlenumber: 33,
      pages: '33-56',
      author: [{ name: 'Smith, Jack', role: 'editor' },
               { name: 'Sprat, Jill', role: 'editor' },
               { name: 'Jones, P. L.' },
               { firstname: 'Alan', middlename: 'T', lastname: 'Jackson' }],
      year: '1987',
      supplement: '33',
      publisher: 'Some Publisher',
      journal: { name: 'Some Journal Name', volume: 33, issue: 32, year: 1999 },
      conference: { name: 'The Big Conference', year: 2345, number: 33, location: 'Knoxville, TN', city: 'Knoxville', statecountry: 'TN' }
    }
  end

  let(:conference_pub_in_book_hash) do
    { title: 'My test title',
      type: 'paper-conference',
      articlenumber: 33,
      pages: '33-56',
      author: [{ name: 'Smith, Jack', role: 'editor' },
               { name: 'Sprat, Jill', role: 'editor' },
               { name: 'Jones, P. L.' },
               { firstname: 'Alan', middlename: 'T', lastname: 'Jackson' }],
      year: '1987',
      publisher: 'Smith Books',
      booktitle: 'The Giant Book of Giant Ideas',
      conference: { name: 'The Big Conference', year: 2345, number: 33, location: 'Knoxville, TN', city: 'Knoxville', statecountry: 'TN' }
    }
  end

  let(:conference_pub_in_series_hash) do
    { title: 'My test title',
      type: 'paper-conference',
      articlenumber: 33,
      pages: '33-56',
      author: [{ name: 'Smith, Jack', role: 'editor' },
               { name: 'Sprat, Jill', role: 'editor' },
               { name: 'Jones, P. L.' },
               { firstname: 'Alan', middlename: 'T', lastname: 'Jackson' }],
      year: '1987',
      publisher: 'Smith Books',
      booktitle: 'The Giant Book of Giant Ideas',
      conference: { name: 'The Big Conference', year: 2345, number: 33, location: 'Knoxville, TN', city: 'Knoxville', statecountry: 'TN' },
      series: { title: 'The book series for kings and queens', volume: 1, number: 4, year: 1933 }
    }
  end

  let(:conference_pub_in_nothing_hash) do
    { title: 'My test title',
      type: 'speech',
      author: [
        { name: 'Jones, P. L.' },
        { firstname: 'Alan', middlename: 'T', lastname: 'Jackson' }],
      conference: { name: 'The Big Conference', year: '1999', number: 33, location: 'Knoxville, TN', city: 'Knoxville', statecountry: 'TN' }
    }
  end

  let(:book_pub_hash) do
    { title: 'My test title',
      type: 'book',
      author: [
        { name: 'Jones, P. L.' },
        { firstname: 'Alan', middlename: 'T', lastname: 'Jackson' }],
      year: '1987',
      publisher: 'Smith Books',
      booktitle: 'The Giant Book of Giant Ideas'
    }
  end

  let(:book_pub_with_editors_hash) do
    { title: 'My test title',
      type: 'book',
      author: [{ name: 'Smith, Jack', role: 'editor' },
               { name: 'Sprat, Jill', role: 'editor' },
               { name: 'Jones, P. L.' },
               { firstname: 'Alan', middlename: 'T', lastname: 'Jackson' }],
      year: '1987',
      publisher: 'Smith Books',
      booktitle: 'The Giant Book of Giant Ideas'
    }
  end

  let(:series_pub_hash) do
    { title: 'My test title',
      type: 'book',
      author: [{ name: 'Smith, Jack', role: 'editor' },
               { name: 'Sprat, Jill', role: 'editor' },
               { name: 'Jones, P. L.' },
               { firstname: 'Alan', middlename: 'T', lastname: 'Jackson' }],
      year: '1987',
      publisher: 'Smith Books',
      booktitle: 'The Giant Book of Giant Ideas',
      series: { title: 'The book series for Big Ideas', volume: 1, number: 4, year: 1933 }
    }
  end

  let(:article_pub_hash) do
    { title: 'My test title',
      type: 'article',
      pages: '3-6',
      author: [{ name: 'Smith, Jack', role: 'editor' },
               { name: 'Sprat, Jill', role: 'editor' },
               { name: 'Jones, P. L.' },
               { firstname: 'Alan', middlename: 'T', lastname: 'Jackson' }],
      year: '1987',
      publisher: 'Some Publisher',
      journal: { name: 'Some Journal Name', volume: 33, issue: 32, year: 1999 }
    }
  end

  let(:pub_hash) do
    { provenance: 'sciencewire',
      pmid: '15572175',
      sw_id: '6787731',
      title:       'New insights into the expression and function of neural connexins with transgenic mouse mutants',
      abstract_restricted:       'Gap junctions represent direct intercellular conduits between contacting cells. The subunit proteins of these conduits are called connexins. To date, 20 and 21 connexin genes have been described in the mouse and human genome, respectiv',
      author:       [{ name: 'Sohl,G,' },
                     { name: 'Odermatt,B,' },
                     { name: 'Maxeiner,S,' },
                     { name: 'Degen,J,' },
                     { name: 'Willecke,K,' },
                     { name: 'SecondLast,T,' },
                     { name: 'Last,O' }],
      year: '2004',
      date: '2004-12-01T00:00:00',
      authorcount: '6',
      documenttypes_sw: ['Article'],
      type: 'article',
      documentcategory_sw: 'Conference Proceeding Document',
      publicationimpactfactorlist_sw:       ['4.617,2004,ExactPublicationYear', '10.342,2011,MostRecentYear'],
      publicationcategoryrankinglist_sw:       ['28/198;NEUROSCIENCES;2004;SC;ExactPublicationYear',
                                                '10/242;NEUROSCIENCES;2011;SC;MostRecentYear'],
      numberofreferences_sw: '159',
      timescited_sw_retricted: '40',
      timenotselfcited_sw: '30',
      authorcitationcountlist_sw: '1,2,38|2,0,40|3,3,37|4,0,40|5,10,30',
      rank_sw: '',
      ordinalrank_sw: '67',
      normalizedrank_sw: '',
      newpublicationid_sw: '',
      isobsolete_sw: 'false',
      publisher: 'ELSEVIER SCIENCE BV',
      city: 'AMSTERDAM',
      stateprovince: '',
      country: 'NETHERLANDS',
      pages: '245-259',
      issn: '0165-0173',
      journal:       { name: 'BRAIN RESEARCH REVIEWS',
                       volume: '47',
                       issue: '1-3',
                       pages: '245-259',
                       identifier:         [{ type: 'issn',
                                              id: '0165-0173',
                                              url: Settings.SULPUB_ID.SEARCHWORKS_URI + '0165-0173' },
                                            { type: 'doi',
                                              id: '10.1016/j.brainresrev.2004.05.006',
                                              url: 'http://dx.doi.org/10.1016/j.brainresrev.2004.05.006' }] },
      abstract:       'Gap junctions represent direct intercellular conduits between contacting cells. The subunit proteins of these conduits are called connexins. To date, 20 and 21 connexin genes have been described in the mouse and human genome, respectiv',
      last_updated: '2013-07-23 22:06:49 UTC',
      authorship:       [{ cap_profile_id: 8804,
                           sul_author_id: 2579,
                           status: 'unknown',
                           visibility: 'private',
                           featured: false }]
    }
  end
  let(:technical_report_online_pub_hash) do
    {
      title: 'Laws of Attrition: Crackdown on Russia’s Civil Society After Putin’s Return to the Presidency',
      type: 'technicalReport',
      pages: '',
      author: [{ name: 'Gorbunova, Yulia' }],
      year: '2013',
      publisher: 'Human Rights Watch',
      publicationUrl: 'http://www.hrw.org/reports/2013/04/24/laws-attrition',
      publicationUrlLabel: '',
      publicationSource: 'New York'
    }
  end
  let(:technical_report_print_pub_hash) do
    {
      title: 'Laws of Attrition: Crackdown on Russia’s Civil Society After Putin’s Return to the Presidency',
      type: 'technicalReport',
      author: [
        { name: 'Gorbunova, Yulia' },
        { name: 'Baranov, Konstantin' },
      ],
      year: '2013',
      publisher: 'Human Rights Watch',
      publicationUrl: '',
      publicationUrlLabel: '',
      publicationSource: 'New York'
    }
  end

  # describe "#sync_publication_hash" do
  #   context " with multiple contributions " do
  #
  #     it " writes the correct authorship field to the pub_hash "
  #         pending
  #       end
  #     it " creates a new contribution for a new authorship entry in the pub_hash "
  #         pending
  #       end
  #   end
  # end

  describe '#to_chicago_citation' do
    context 'with more than 5 authors' do
      it 'builds citations with just the first 5 and suppends et al' do
        h = PubHash.new(pub_hash)
        cite = h.to_chicago_citation
        expect(cite).to match(/^Sohl, G./)
        expect(cite).to include('B. Odermatt')
        expect(cite).to include('S. Maxeiner')
        expect(cite).to include('J. Degen')
        expect(cite).to include('K. Willecke')
        expect(cite).to include('et al.')
        expect(cite).to_not include(', and')
        expect(cite).to_not include('SecondLast')
        expect(cite).to_not include('Last')
        expect(h.pub_hash[:author]).to_not include(name: 'et al.')
      end
    end
    it 'includes capitalized title' do
      h = PubHash.new(pub_hash)
      cite = h.to_chicago_citation
      expect(cite).to include('New Insights Into the Expression and Function of Neural Connexins With Transgenic Mouse Mutants')
    end

    it 'includes authors from single name field' do
      h = PubHash.new(article_pub_hash)
      cite = h.to_chicago_citation
      expect(cite).to include('Jones, P. L.')
    end

    it 'includes authors from compound name field' do
      h = PubHash.new(article_pub_hash)
      cite = h.to_chicago_citation
      expect(cite).to include('Alan T. Jackson')
    end

    context 'for conference' do
      context 'published in book' do
        it 'includes book information' do
          conference_in_book = PubHash.new(conference_pub_in_book_hash)
          cite = conference_in_book.to_chicago_citation
          expect(cite).to include(conference_pub_in_book_hash[:booktitle])
          expect(cite).to include(conference_pub_in_book_hash[:publisher])
          expect(cite).to include(conference_pub_in_book_hash[:year])
        end
      end

      context 'published in journal' do
        it 'includes journal information' do
          conference_in_journal = PubHash.new(conference_pub_in_journal_hash)
          cite = conference_in_journal.to_chicago_citation
          expect(cite).to include(conference_pub_in_journal_hash[:title].titlecase)
          expect(cite).to include(conference_pub_in_journal_hash[:pages])
          expect(cite).to include(conference_pub_in_journal_hash[:year])
          expect(cite).to include(conference_pub_in_journal_hash[:journal][:name])
        end
      end

      context 'published in book series' do
        it 'includes book and series information' do
          conference_in_book_series = PubHash.new(conference_pub_in_series_hash)
          cite = conference_in_book_series.to_chicago_citation
          expect(cite).to include('The Giant Book of Giant Ideas')
          expect(cite).to include('The Book Series For Kings and Queens')
          expect(cite).to include(conference_pub_in_series_hash[:publisher])
          expect(cite).to include(conference_pub_in_series_hash[:year])
        end
      end
    end

    context 'for book' do
      it 'includes book information' do
        book = PubHash.new(book_pub_hash)
        cite = book.to_chicago_citation
        expect(cite).to include(book_pub_hash[:booktitle])
        expect(cite).to include(book_pub_hash[:publisher])
        expect(cite).to include(book_pub_hash[:year])
      end

      it 'includes editors' do
        book = PubHash.new(book_pub_with_editors_hash)
        cite = book.to_chicago_citation
        expect(cite).to include('Jack Smith')
        expect(cite).to include('Jill Sprat')
      end
      it 'includes authors' do
        book = PubHash.new(book_pub_hash)
        cite = book.to_chicago_citation
        expect(cite).to include('Jones, P. L.')
        expect(cite).to include('Alan T. Jackson')
      end
    end

    context 'for article' do
      it 'includes article information' do
        article_in_journal = PubHash.new(article_pub_hash)
        cite = article_in_journal.to_chicago_citation
        expect(cite).to include(article_pub_hash[:title].titlecase)
        expect(cite).to include(article_pub_hash[:year])
        expect(cite).to include(article_pub_hash[:journal][:name])
      end
      it 'includes journal volume issue and pages' do
        article_in_journal = PubHash.new(article_pub_hash)
        cite = article_in_journal.to_chicago_citation
        expect(cite).to include("#{article_pub_hash[:journal][:volume]} (#{article_pub_hash[:journal][:issue]}): #{article_pub_hash[:pages]}")
      end

      it 'excludes editors' do
        article_in_journal = PubHash.new(article_pub_hash)
        cite = article_in_journal.to_chicago_citation
        expect(cite).to_not include('Jack Smith')
        expect(cite).to_not include('Jill Sprat')
      end
      it 'includes authors' do
        article_in_journal = PubHash.new(article_pub_hash)
        cite = article_in_journal.to_chicago_citation
        expect(cite).to include('Jones, P. L.')
        expect(cite).to include('Alan T. Jackson')
      end
    end
  end

  describe '#to_mla_citation' do
    context 'with more than 5 authors' do
      it 'builds citations with just the first 5' do
        h = PubHash.new(pub_hash)
        cite = h.to_mla_citation
        expect(cite).to match(/^Sohl, G./)
        expect(h.pub_hash[:author]).to_not include(name: 'et al.')
      end
    end

    context 'with etal flag' do
      let(:et_hash) do
        { provenance: 'sciencewire',
          pmid: '15572175',
          sw_id: '6787731',
          title:         'New insights into the expression and function of neural connexins with transgenic mouse mutants',
          abstract_restricted:         'Gap junctions represent direct intercellular conduits between contacting cells. The subunit proteins of these conduits are called connexins. To date, 20 and 21 connexin genes have been described in the mouse and human genome, respectiv',
          author:         [{ name: 'Sohl,G,' },
                           { name: 'Odermatt,B,' }],
          etal: true,
          year: '2004',
          date: '2004-12-01T00:00:00',
          authorcount: '6',
          documenttypes_sw: ['Article'],
          type: 'article',
          documentcategory_sw: 'Conference Proceeding Document',
          numberofreferences_sw: '159',
          publisher: 'ELSEVIER SCIENCE BV',
          city: 'AMSTERDAM',
          stateprovince: '',
          country: 'NETHERLANDS',
          pages: '245-259',
          issn: '0165-0173',
          journal:           { name: 'BRAIN RESEARCH REVIEWS',
                               volume: '47',
                               issue: '1-3',
                               pages: '245-259',
                               identifier:             [{ type: 'issn',
                                                          id: '0165-0173',
                                                          url: Settings.SULPUB_ID.SEARCHWORKS_URI + '0165-0173' },
                                                        { type: 'doi',
                                                          id: '10.1016/j.brainresrev.2004.05.006',
                                                          url: 'http://dx.doi.org/10.1016/j.brainresrev.2004.05.006' }] },
          abstract:                 'Gap junctions represent direct intercellular conduits between contacting cells. The subunit proteins of these conduits are called connexins. To date, 20 and 21 connexin genes have been described in the mouse and human genome, respectiv',
          last_updated: '2013-07-23 22:06:49 UTC',
          authorship:                 [{ cap_profile_id: 8804,
                                         sul_author_id: 2579,
                                         status: 'unknown',
                                         visibility: 'private',
                                         featured: false }]
                  }
      end

      it 'adds et al whenever the flag is true' do
        skip 'have to further modify CSL or code somehow'
        h = PubHash.new(et_hash)
        cite = h.to_chicago_citation
        expect(cite).to match(/^Sohl, G./)
        expect(cite).to match(/et al./)
        expect(h.pub_hash[:author]).to_not include(name: 'et al.')
      end
    end
  end
  describe 'Other paper' do
    let(:other_paper) { create(:other_paper) }
    it 'creates a citation'
  end
  describe 'Technical report' do
    let(:technical_report) { create(:technical_report) }
    ##
    # An example given from a direct import of a record entered in the CAP UAT environment.
    context 'from cap with minimum required fields' do
      it 'creates a citation' do
        pub_hash = PubHash.new(JSON.parse(technical_report.source_data, symbolize_names: true))
        expect(pub_hash.to_chicago_citation)
          .to eq "Mangiafico, Peter A. 2016. <i>This Is Peter'S Technical Report On the Revs Digital Library</i>5. Series Name. Stanford, CA : Stanford University. http://revslib.stanford.edu."
        expect(pub_hash.to_mla_citation)
          .to eq "Mangiafico, Peter A. <i>This Is Peter'S Technical Report On the Revs Digital Library</i>. Stanford, CA : Stanford University, 2016. Web. Series Name."
        expect(pub_hash.to_apa_citation)
          .to eq "Mangiafico, P. A. (2016). <i>This is Peter's Technical Report on the Revs Digital Library</i> (No. 5) (1-5). Stanford, CA : Stanford University. Retrieved from http://revslib.stanford.edu"
      end
    end
    context 'given fixture' do
      context 'an online technical report' do
        let(:pub_hash) { PubHash.new(technical_report_online_pub_hash) }
        ##
        # Example taken from: http://www.easybib.com/guides/citation-guides/chicago-turabian/how-to-cite-a-report-chicago-turabian/
        # Differences: using the Sul-Pub preferred Chicago author-date format and a strange capitalization on "'s"
        it 'returns a Chicago citation' do
          expect(pub_hash.to_chicago_citation)
            .to eq 'Gorbunova, Yulia. 2013. <i>Laws of Attrition: Crackdown On Russia’S Civil Society After Putin’S Return To the Presidency</i>. New York: Human Rights Watch. http://www.hrw.org/reports/2013/04/24/laws-attrition.'
        end
        ##
        # Example taken from: http://www.easybib.com/guides/citation-guides/apa-format/how-to-cite-a-report-apa/
        # Differences: not showing "Retrieved from 'Agency name' website:"
        it 'returns an APA citation' do
          expect(pub_hash.to_apa_citation)
            .to eq 'Gorbunova, Y. (2013). <i>Laws of Attrition: Crackdown on Russia’s Civil Society After Putin’s Return to the Presidency</i>. New York: Human Rights Watch. Retrieved from http://www.hrw.org/reports/2013/04/24/laws-attrition'
        end
      end
      ##
      # Example take from: http://www.easybib.com/guides/citation-guides/mla-format/how-to-cite-a-report-mla/
      # Differences: using a modified multiple authors format that we already support and a strange capitalization on "'s"
      context 'a print technical report with multiple authors' do
        it 'returns a MLA citation' do
          expect(PubHash.new(technical_report_print_pub_hash).to_mla_citation)
            .to eq 'Gorbunova, Yulia, and Konstantin Baranov. <i>Laws of Attrition: Crackdown On Russia’S Civil Society After Putin’S Return To the Presidency</i>. New York: Human Rights Watch, 2013. Print.'
        end
      end
    end
  end
end
