class PubmedHarvester
  # Searches locally (twice), then ScienceWire/WOS, then Pubmed for a publication by PubmedId
  # Is paranoid, searches both publications and publication_identifiers identifiers for pmid
  # @param [String] pmid Pubmed ID
  # @return [Array<Hash>] publications in BibJson format or, if none found, an empty Array
  def self.search_all_sources_by_pmid(pmid)
    pub = Publication.find_by(pmid: pmid) || Publication.find_by_pmid_pub_id(pmid)
    return [pub.pub_hash] if pub && pub.authoritative_pmid_source?
    result = fetch_remote_pubmed(pmid)
    return result unless result.empty?
    [pub.pub_hash] # non-authoritative local hit
  end

  # @param [String] pmid Pubmed ID
  # @return [Array<Hash>] pub_hashes or an empty Array
  def self.fetch_remote_pubmed(pmid)
    if Settings.SCIENCEWIRE.enabled
      sw_records_doc = ScienceWireClient.new.pull_records_from_sciencewire_for_pmids(pmid)
      result = sw_records_doc.xpath('//PublicationItem').map do |sw_doc|
        add_citation(SciencewireSourceRecord.convert_sw_publication_doc_to_hash(sw_doc))
      end
      return result unless result.empty?
    end

    # note: only works because all results expected to fit inside one "batch"
    if Settings.WOS.enabled
      result = WebOfScience.queries.retrieve_by_pmid([pmid]).next_batch.map { |rec| add_citation(rec.pub_hash) }
      return result unless result.empty?
    end

    # PubMed, oddly enough, the last resort
    pm_xml = PubmedClient.new.fetch_records_for_pmid_list(pmid)
    Nokogiri::XML(pm_xml).xpath('//PubmedArticle').map do |doc|
      add_citation(PubmedSourceRecord.new.source_as_hash(doc))
    end
  end
  private_class_method :fetch_remote_pubmed

  # @param [Hash] pub_hash modifies passed hash to include citation k/v pairs
  # @return [Hash] the same modified hash
  def self.add_citation(pub_hash)
    pub_hash.update Csl::Citation.new(pub_hash).citations
  end
  private_class_method :add_citation
end
