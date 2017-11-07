require 'citeproc/ruby'
# You can install more recent styles using the 'csl-styles' gem or you can just
# download the styles you need (just point CSL::Style.root to the directory and
# you can load any style with just its name using CSL::Style.load).
require 'csl/styles'

class PubHash
  attr_reader :csl_renderer
  attr_reader :pub_hash

  CSL_STYLE_APA = CSL::Style.load('apa')
  CSL_STYLE_MLA = CSL::Style.load('modern-language-association')

  CSL_STYLE_CHICAGO = CSL::Style.load('chicago-author-date')
  CSL_STYLE_CHICAGO_ET_AL = begin
    # Modify the bibliography attributes so it uses 'et al.' after 5 authors
    style_et_al = CSL::Style.load('chicago-author-date')
    style_et_al.bibliography.attributes['et-al-min'] = 1
    style_et_al.bibliography.attributes['et-al-use-first'] = 5
    style_et_al
  end

  def initialize(hash)
    @pub_hash = hash
  end

  # Generates a new render instance every time, so it has no history of any prior citations.
  # When it has history, it can assume that subsequent citations can refer to earlier citations,
  # which has a different style for the subsequent citations.
  # @param csl_citation_data [Hash] a CSL citation document
  # @param csl_style [CSL::Style] a CSL citation style
  # @return citation [String] a bibliographic citation
  def generate_csl_citation(csl_citation_data, csl_style)
    item = CiteProc::CitationItem.new(id: 'sulpub')
    item.data = CiteProc::Item.new(csl_citation_data)
    csl_renderer = CiteProc::Ruby::Renderer.new(format: 'html')
    csl_renderer.render item, csl_style.bibliography
  end

  def to_chicago_citation
    if csl_doc['author'].count > 5
      generate_csl_citation(csl_doc, CSL_STYLE_CHICAGO_ET_AL)
    else
      generate_csl_citation(csl_doc, CSL_STYLE_CHICAGO)
    end
  end

  def to_mla_citation
    generate_csl_citation(csl_doc, CSL_STYLE_MLA)
  end

  def to_apa_citation
    generate_csl_citation(csl_doc, CSL_STYLE_APA)
  end

  def csl_doc
    @csl_doc ||= begin

      ##
      # Parse authors for various provenance data:
      # - batch
      # - cap
      # - pubmed
      # - sciencewire
      authors = pub_hash[:author] || []
      case pub_hash[:provenance]
      when /batch/i
        # This is from BibtexIngester.convert_bibtex_record_to_pub_hash
        @citeproc_authors ||= bibtex_authors_to_csl(authors)
        @citeproc_editors ||= [] # there are no editors
      when /cap/i
        # This is a CAP manual submission
        @citeproc_authors ||= cap_authors_to_csl(authors, 'author')
        @citeproc_editors ||= cap_authors_to_csl(authors, 'editor')
      when /pubmed/i
        # This is a PubMed publication and the author is created in
        # PubmedSourceRecord.convert_pubmed_publication_doc_to_hash
        @citeproc_authors ||= pubmed_authors_to_csl(authors)
        @citeproc_editors ||= [] # there are no editors
      when /sciencewire/i
        # This is a ScienceWire publication and the author is created in
        # SciencewireSourceRecord.convert_sw_publication_doc_to_hash
        @citeproc_authors ||= sw_authors_to_csl(authors)
        @citeproc_editors ||= [] # there are no editors
      else
        citeproc_authors # calls parse_authors
        citeproc_editors # calls parse_authors
      end

      if pub_hash[:provenance] =~ /cap/i
        case pub_hash[:type]
        when 'workingPaper', 'technicalReport'
          # Map a CAP 'workingPaper' or 'technicalReport' to a CSL 'report'
          return create_csl_report
        end
        ##
        # Other doc-types include:
        # - article
        # - book
        # - inbook
        # - inproceedings
      end

      cit_data_hash = {
        'id' => 'sulpub',
        'type' => pub_hash[:type],
        'author' => citeproc_authors,
        'title' => pub_hash[:title]
      }

      # Access to abstracts may be restricted by license agreements with data providers.
      # cit_data_hash["abstract"] = pub_hash[:abstract] if pub_hash[:abstract].present?

      cit_data_hash['chapter-number'] = pub_hash[:articlenumber] if pub_hash[:articlenumber].present?
      cit_data_hash['page'] = pub_hash[:pages] if pub_hash[:pages].present?
      cit_data_hash['publisher'] = pub_hash[:publisher] if pub_hash[:publisher].present?

      # Add series information if it exists.
      if pub_hash.key?(:series)
        if pub_hash[:series][:title].present?
          cit_data_hash['type'] = 'book'
          cit_data_hash['collection-title'] = pub_hash[:series][:title]
        end
        cit_data_hash['volume'] = pub_hash[:series][:volume] if pub_hash[:series][:volume].present?
        cit_data_hash['number'] = pub_hash[:series][:number] if pub_hash[:series][:number].present?
        cit_data_hash['issued'] = { 'date-parts' => [[pub_hash[:series][:year]]] } if pub_hash[:series][:year].present?
      end

      # Add journal information if it exists.
      if pub_hash.key?(:journal)
        if pub_hash[:journal][:name].present?
          cit_data_hash['type'] = 'article-journal'
          cit_data_hash['container-title'] = pub_hash[:journal][:name]
        end
        cit_data_hash['volume'] = pub_hash[:journal][:volume] if pub_hash[:journal][:volume].present?
        cit_data_hash['issue'] = pub_hash[:journal][:issue] if pub_hash[:journal][:issue].present?
        cit_data_hash['issued'] = { 'date-parts' => [[pub_hash[:journal][:year]]] } if pub_hash[:journal][:year].present?
        cit_data_hash['number'] = pub_hash[:supplement] if pub_hash[:supplement].present?
      end

      # Add any conference information, if it exists in a conference object;
      # this overrides the sciencewire fields above if both exist, which they shouldn't.
      if pub_hash.key?(:conference)
        cit_data_hash['event'] = pub_hash[:conference][:name] if pub_hash[:conference][:name].present?
        cit_data_hash['event-date'] = pub_hash[:conference][:startdate] if pub_hash[:conference][:startdate].present?
        # override the startdate if there is a year:
        cit_data_hash['event-date'] = { 'date-parts' => [[pub_hash[:conference][:year]]] } if pub_hash[:conference][:year].present?
        cit_data_hash['number'] = pub_hash[:conference][:number] if pub_hash[:conference][:number].present?
        # favors city/state over location
        if pub_hash[:conference][:city].present? || pub_hash[:conference][:statecountry].present?
          cit_data_hash['event-place'] = pub_hash[:conference][:city] || ''
          if pub_hash[:conference][:statecountry].present?
            cit_data_hash['event-place'] << ',' if cit_data_hash['event-place'].present?
            cit_data_hash['event-place'] << pub_hash[:conference][:statecountry]
          end
        elsif pub_hash[:conference][:location].present?
          cit_data_hash['event-place'] = pub_hash[:conference][:location]
        end
        # cit_data_hash["DOI"] = pub_hash[:conference][:DOI] if pub_hash[:conference][:DOI].present?
      end

      # Use a year at the top level if it exists, i.e, override any year we'd gotten above from journal or series.
      cit_data_hash['issued'] = { 'date-parts' => [[pub_hash[:year]]] } if pub_hash[:year].present?
      # Add book title if it exists, which indicates this pub is a chapter in the book.
      if pub_hash[:booktitle].present?
        cit_data_hash['type'] = 'book'
        cit_data_hash['container-title'] = pub_hash[:booktitle]
      end

      if cit_data_hash['type'].to_s.casecmp('book').zero? && citeproc_editors.present?
        cit_data_hash['editor'] = citeproc_editors
      end

      ##
      # For a CAP type "caseStudy" just use a "book"
      cit_data_hash['type'] = 'book' if pub_hash[:type] == 'caseStudy'

      ##
      # Mapping custom fields from the CAP system.
      cit_data_hash['URL'] = pub_hash[:publicationUrl] if pub_hash[:publicationUrl].present?
      cit_data_hash['publisher-place'] = pub_hash[:publicationSource] if pub_hash[:publicationSource].present?

      cit_data_hash
    end
  end

  private

    # Report – A document containing the findings of an individual or group.
    # Can include a technical paper, publication, issue brief, or working paper.
    #
    # The Zotero and Mendeley mappings to a CSL report guided this implementation, see
    # http://aurimasv.github.io/z2csl/typeMap.xml#map-report
    # http://support.mendeley.com/customer/portal/articles/364144-csl-type-mapping
    def create_csl_report
      csl_report = {}
      csl_report['id'] = 'sulpub'
      csl_report['type'] = 'report'
      csl_report['author'] = citeproc_authors if citeproc_authors.present?
      csl_report['editor'] = citeproc_editors if citeproc_editors.present?
      csl_report['title'] = pub_hash[:title] if pub_hash[:title].present?
      csl_report['abstract'] = pub_hash[:abstract] if pub_hash[:abstract].present?
      csl_report['publisher'] = pub_hash[:publisher] if pub_hash[:publisher].present?
      csl_report['publisher-place'] = pub_hash[:publicationSource] if pub_hash[:publicationSource].present?
      # Date Accessed -> accessed
      if pub_hash[:year].present?
        csl_report['issued'] = {
          'date-parts' => [[ pub_hash[:year] ]]
        }
      end
      url = pub_hash[:publicationUrl]
      csl_report['URL'] = url if url.present?
      series = pub_hash[:series]
      if series.present?
        csl_report['collection-title'] = series[:title] if series[:title].present?
        csl_report['volume'] = series[:volume] if series[:volume].present?
        csl_report['number'] = series[:number] if series[:number].present?
      end
      csl_report['page'] = pub_hash[:pages] if pub_hash[:pages].present?
      csl_report
    end

    def citeproc_authors
      @citeproc_authors ||= parse_authors[:authors]
    end

    def citeproc_editors
      @citeproc_editors ||= parse_authors[:editors]
    end

    # Convert BibTexIngester authors into CSL authors
    # @param [Array<Hash>] BibTexIngester authors array of hash data
    # @return [Array<Hash>] CSL authors array of hash data
    def bibtex_authors_to_csl(bibtex_authors)
      bibtex_authors.map do |author|
        author = author.symbolize_keys
        next if author[:name].blank?
        family, given = author[:name].split(',')
        { 'family' => family, 'given' => given }
      end
    end

    # Convert CAP authors into CSL authors
    # @param [Array<Hash>] CAP authors array of hash data
    # @return [Array<Hash>] CSL authors array of hash data
    def cap_authors_to_csl(cap_authors, role = 'author')
      cap_authors.map do |author|
        author = author.symbolize_keys
        next unless author[:role].to_s.casecmp(role).zero?
        Csl::AuthorName.new(author).to_csl_author
      end.compact
    end

    # Convert PubMed authors into CSL authors, see also
    # PubmedSourceRecord.convert_pubmed_publication_doc_to_hash
    # @param [Array<Hash>] PubMed authors array of hash data
    # @return [Array<Hash>] CSL authors array of hash data
    def pubmed_authors_to_csl(pubmed_authors)
      pubmed_authors.map do |author|
        author = author.symbolize_keys
        Csl::AuthorName.new(author).to_csl_author
      end.compact
    end

    # Convert ScienceWire authors into CSL authors, see also
    # SciencewireSourceRecord.convert_sw_publication_doc_to_hash
    # @param [Array<Hash>] ScienceWire authors array of hash data
    # @return [Array<Hash>] CSL authors array of hash data
    def sw_authors_to_csl(sw_authors)
      # ScienceWire AuthorList is split('|') into an array of authors
      sw_authors.map do |author|
        # Each ScienceWire author is a CSV value: 'Lastname,Firstname,Middlename'
        last, first, middle = author[:name].split(',')
        Csl::AuthorName.new(
          lastname: last,
          firstname: first,
          middlename: middle
        ).to_csl_author
      end.compact
    end

    def parse_authors
      # All the pub_hash[:author] data is assumed be an editor or an author and
      # the only way to tell is when the editor has role=='editor'
      pub_hash_authors = pub_hash[:author] || []
      authors = pub_hash_authors.reject { |a| a[:role].to_s.casecmp('editor').zero? }
      editors = pub_hash_authors.select { |a| a[:role].to_s.casecmp('editor').zero? }
      if authors.length > 5
        # we pass the first five  authorsand the very last author because some
        # formats add the very last name when using et-al. the CSL should drop the sixth name if unused.
        # We could in fact pass all the author names to the CSL processor and let it
        # just take the first five, but that seemed to crash the processor for publications
        # with a lot of authors (e.g, 2000 authors)
        authors = authors[0..4]
        authors << pub_hash[:author].last
        #   authors << { :name => "et al." }
        # elsif pub_hash[:etal]
        #   authors = pub_hash[:author].collect { |a| a }
        #   authors << { :name => "et al." }
      end
      {
        authors: authors.map { |author| parse_author_name(author) }.compact,
        editors: editors.map { |author| parse_author_name(author) }.compact
      }
    end

    # Extract { 'family' => last_name, 'given' => rest_of_name } or
    # return nil if the the family name is blank.
    # @return [Hash<String => String>|nil]
    def parse_author_name(author)
      last_name = author[:lastname]
      rest_of_name = ''

      # Use parsed name parts, if available.  Otherwise use :name, if available.
      # Add period after single character (initials).
      if last_name.present?
        %i(firstname middlename).map { |k| author[k] }.reject(&:blank?).each do |name_part|
          rest_of_name << ' ' << name_part
          rest_of_name << '.' if name_part.length == 1
        end
      end

      if last_name.blank? && author[:name].present?
        author[:name].split(',').each_with_index do |name_part, index|
          if index.zero?
            last_name = name_part
          else
            rest_of_name << ' ' << name_part
            rest_of_name << '.' if name_part.length == 1
          end
        end
      end

      return nil if last_name.blank?
      { 'family' => last_name, 'given' => rest_of_name }
    end
end

