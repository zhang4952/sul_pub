require 'nokogiri'
require 'settings'
require 'activerecord-import'
require 'dotiw'

class SciencewireSourceRecord < ActiveRecord::Base

  	attr_accessible :is_active, :lock_version, :pmid, :sciencewire_id, :source_data, :source_fingerprint
  	#validates_uniqueness_of :sciencewire_id

  	@@sw_conference_proceedings_type_strings ||= Settings.sw_doc_type_mappings.conference.split(',')
	@@sw_book_type_strings ||= Settings.sw_doc_type_mappings.book.split(',')

	include ActionView::Helpers::DateHelper
	# one instance method, the rest are class methods
	def get_source_as_hash
		SciencewireSourceRecord.convert_sw_publication_doc_to_hash(Nokogiri::XML(self.source_data).xpath('//PublicationItem'))
	end

	def self.get_pub_by_pmid(pmid)
		sw_pub_hash = get_sciencewire_hash_for_pmid(pmid)
        unless sw_pub_hash.nil?
          pub = Publication.create(
            active: true,
            title: sw_pub_hash[:title],
            year: sw_pub_hash[:year],
     		pages: sw_pub_hash[:pages],
     		issn: sw_pub_hash[:issn],
          	publication_type: sw_pub_hash[:type],
            sciencewire_id: sw_pub_hash[:sw_id],
            pmid: pmid)
          pub.build_from_sciencewire_hash(sw_pub_hash)
          pub.sync_publication_hash_and_db

      	end
      	pub
	end

	def self.get_pub_by_sciencewire_id(sciencewire_id)
		sw_pub_hash = get_sciencewire_hash_for_sw_id(sciencewire_id)
        unless sw_pub_hash.nil?
          pub = Publication.create(
            active: true,
            title: sw_pub_hash[:title],
            year: sw_pub_hash[:year],
     		pages: sw_pub_hash[:pages],
     		issn: sw_pub_hash[:issn],
          	publication_type: sw_pub_hash[:type],
            sciencewire_id: sciencewire_id,
            pmid: sw_pub_hash[:pmid])
          pub.build_from_sciencewire_hash(sw_pub_hash)
          pub.sync_publication_hash_and_db
      	end
      	pub
	end

	def self.get_sciencewire_hash_for_sw_id(sciencewire_id)
  		sciencewire_source_record = get_sciencewire_source_record_for_sw_id(sciencewire_id)
  		unless sciencewire_source_record.nil?
  			sciencewire_source_record.get_source_as_hash
  		end
  	end

	def self.get_sciencewire_hash_for_pmid(pmid)
  		sciencewire_source_record = get_sciencewire_source_record_for_pmid(pmid)
  		unless sciencewire_source_record.nil?
  			sciencewire_source_record.get_source_as_hash
  		end
  	end

	def self.get_sciencewire_source_record_for_sw_id(sw_id)
  		SciencewireSourceRecord.where(sciencewire_id: sw_id).first || SciencewireSourceRecord.get_sciencewire_source_record_from_sciencewire_by_sw_id(sw_id)
  	end

  	def self.get_sciencewire_source_record_for_pmid(pmid)
  		SciencewireSourceRecord.where(pmid: pmid).first || SciencewireSourceRecord.get_sciencewire_source_record_from_sciencewire(pmid)
  	end

  	def self.get_sciencewire_source_record_from_sciencewire(pmid)
  		get_and_store_sw_source_records([pmid])
  		SciencewireSourceRecord.where(pmid: pmid).first
  	end

	def self.get_sciencewire_source_record_from_sciencewire_by_sw_id(sciencewire_id)
  		get_and_store_sw_source_record_for_sw_id(sciencewire_id)
  		SciencewireSourceRecord.where(sciencewire_id: sciencewire_id).first
  	end

  	def self.get_and_store_sw_source_record_for_sw_id(sciencewire_id)
  		sw_record_doc = ScienceWireClient.new.get_sw_xml_source_for_sw_id(sciencewire_id)
	    pmid = sw_record_doc.xpath("PMID").text
	    #sciencewire_id = sw_record_doc.xpath("PublicationItemID").text

	    SciencewireSourceRecord.where(sciencewire_id: sciencewire_id).first_or_create(
	                      :source_data => sw_record_doc.to_xml,
	                      :is_active => true,
	                      :pmid => pmid,
	                      :source_fingerprint => Digest::SHA2.hexdigest(sw_record_doc))
  	end

	#get and store sciencewire source records for pmid list
	def self.get_and_store_sw_source_records(pmids)
	    sw_records_doc = ScienceWireClient.new.pull_records_from_sciencewire_for_pmids(pmids)
	    count = 0
	    source_records = []
	    sw_records_doc.xpath('//PublicationItem').each do |sw_record_doc|
	      pmid = sw_record_doc.xpath("PMID").text
	      sciencewire_id = sw_record_doc.xpath("PublicationItemID").text
	      begin
	        count += 1
	        pmids.delete(pmid)

	        source_records << SciencewireSourceRecord.new(
	                      :sciencewire_id => sciencewire_id,
	                      :source_data => sw_record_doc.to_xml,
	                      :is_active => true,
	                      :pmid => pmid,
	                      :source_fingerprint => Digest::SHA2.hexdigest(sw_record_doc))

	      rescue => e
	        puts e.message
	        #puts e.backtrace.inspect
	        puts "The offending pmid: " + pmid.to_s
	      end
	    end
	  #  puts source_records.length.to_s + " records about to be created."
	    SciencewireSourceRecord.import source_records
	  #  puts count.to_s + " pmids were processed. "
	  #  puts pmids.length.to_s + " pmids weren't processed: "
	   # cap_pub_data_for_this_batch.each_key { |k| puts k.to_s}
	 end

	def self.save_sw_source_record(sciencewire_id, pmid, incoming_sw_xml_as_string)

	    existing_sw_source_record = SciencewireSourceRecord.where(
	      :sciencewire_id => sciencewire_id).first
	    if existing_sw_source_record.nil?
	    	new_source_fingerprint = get_source_fingerprint(incoming_sw_xml_as_string)
	    	  attrs = {
	    	    :sciencewire_id => sciencewire_id,
            :source_data => incoming_sw_xml_as_string,
            :is_active => true,
            source_fingerprint: new_source_fingerprint
	    	  }
	    	  attrs[:pmid] = pmid unless(pmid.blank?)
	        SciencewireSourceRecord.create(attrs)
	    end
	    # return true or false to indicate if new record was created or one already existed.
	    was_record_created = existing_sw_source_record.nil?
	    was_record_created
	    #elsif existing_sw_source_record.source_fingerprint != new_source_fingerprint
	     #   existing_sw_source_record.update_attributes(
	     #     pmid: pmid,
	     #     source_data: incoming_sw_xml_as_string,
	     #     is_active: true,
	     #     source_fingerprint: new_source_fingerprint
	     #    )

	end

	def self.get_source_fingerprint(sw_record_doc)
	  Digest::SHA2.hexdigest(sw_record_doc)
	end

	def self.source_data_has_changed?(existing_sw_source_record, incoming_sw_source_doc)
	  existing_sw_source_record.source_fingerprint != get_source_fingerprint(incoming_sw_source_doc)
	end

	def self.convert_sw_publication_doc_to_hash(publication)

	    record_as_hash = Hash.new

	    record_as_hash[:provenance] = Settings.sciencewire_source
	    record_as_hash[:pmid] = publication.xpath("PMID").text unless publication.xpath("PMID").blank?
	    record_as_hash[:sw_id] = publication.xpath("PublicationItemID").text
	    record_as_hash[:title] = publication.xpath("Title").text unless publication.xpath("Title").blank?
	    record_as_hash[:abstract_restricted] = publication.xpath("Abstract").text unless publication.xpath("Abstract").blank?
	    record_as_hash[:author] = publication.xpath('AuthorList').text.split('|').collect{|author| {name: author}}

	    record_as_hash[:year] = publication.xpath('PublicationYear').text unless publication.xpath("PublicationYear").blank?
	    record_as_hash[:date] = publication.xpath('PublicationDate').text unless publication.xpath("PublicationDate").blank?

	    record_as_hash[:authorcount] = publication.xpath("AuthorCount").text unless publication.xpath("AuthorCount").blank?

	    record_as_hash[:keywords_sw] = publication.xpath('KeywordList').text.split('|') unless publication.xpath("KeywordList").blank?
	    record_as_hash[:documenttypes_sw] = publication.xpath("DocumentTypeList").text.split('|')
	    sul_document_type = lookup_sw_doc_type(record_as_hash[:documenttypes_sw])
	    record_as_hash[:type] = sul_document_type

	    record_as_hash[:documentcategory_sw] = publication.xpath("DocumentCategory").text unless publication.xpath("DocumentCategory").blank?
	    record_as_hash[:publicationimpactfactorlist_sw] = publication.xpath('PublicationImpactFactorList').text.split('|')  unless publication.xpath("PublicationImpactFactorList").blank?
	    record_as_hash[:publicationcategoryrankinglist_sw] = publication.xpath('PublicationCategoryRankingList').text.split('|')  unless publication.xpath("PublicationCategoryRankingList").blank?
	    record_as_hash[:numberofreferences_sw] = publication.xpath("NumberOfReferences").text unless publication.xpath("NumberOfReferences").blank?
	    record_as_hash[:timescited_sw_retricted] = publication.xpath("TimesCited").text unless publication.xpath("TimesCited").blank?
	    record_as_hash[:timenotselfcited_sw] = publication.xpath("TimesNotSelfCited").text unless publication.xpath("TimesNotSelfCited").blank?
	    record_as_hash[:authorcitationcountlist_sw] = publication.xpath("AuthorCitationCountList").text unless publication.xpath("AuthorCitationCountList").blank?
	    record_as_hash[:rank_sw] =  publication.xpath('Rank').text unless publication.xpath("Rank").blank?
	    record_as_hash[:ordinalrank_sw] = publication.xpath('OrdinalRank').text unless publication.xpath("OrdinalRank").blank?
	    record_as_hash[:normalizedrank_sw] = publication.xpath('NormalizedRank').text unless publication.xpath("NormalizedRank").blank?
	    record_as_hash[:newpublicationid_sw] = publication.xpath('NewPublicationItemID').text unless publication.xpath("NewPublicationItemID").blank?
	    record_as_hash[:isobsolete_sw] = publication.xpath('IsObsolete').text unless publication.xpath("IsObsolete").blank?

	    record_as_hash[:publisher] =  publication.xpath('CopyrightPublisher').text unless publication.xpath("CopyrightPublisher").blank?
	    record_as_hash[:city] = publication.xpath('CopyrightCity').text unless publication.xpath("CopyrightCity").blank?
	    record_as_hash[:stateprovince] = publication.xpath('CopyrightStateProvince').text unless publication.xpath("CopyrightStateProvince").blank?
	    record_as_hash[:country] = publication.xpath('CopyrightCountry').text unless publication.xpath("CopyrightCountry").blank?
	    record_as_hash[:pages] = publication.xpath('Pagination').text unless publication.xpath('Pagination').blank?

	    identifiers = Array.new
	    identifiers << {:type =>'PMID', :id => publication.at_xpath("PMID").text, :url => 'http://www.ncbi.nlm.nih.gov/pubmed/' + publication.xpath("PMID").text } unless publication.at_xpath("PMID").nil? || publication.at_xpath("PMID").text.blank?
	    identifiers << {:type => 'WoSItemID', :id => publication.at_xpath("WoSItemID").text, :url => 'http://ws.isiknowledge.com/cps/openurl/service?url_ver=Z39.88-2004&rft_id=info:ut/' + publication.xpath("WoSItemID").text} unless publication.at_xpath("WoSItemID").nil?
	    identifiers << {:type => 'PublicationItemID', :id => publication.at_xpath("PublicationItemID").text} unless publication.at_xpath("PublicationItemID").nil?

	    # an issn is for either a journal or a book series (international standard series number)
	    issn = {:type => 'issn', :id => publication.xpath('ISSN').text, :url => 'http://searchworks.stanford.edu/?search_field=advanced&number=' + publication.xpath('ISSN').text} unless publication.xpath('ISSN').blank?
	    record_as_hash[:issn] = publication.xpath('ISSN').text unless publication.xpath('ISSN').blank?
	    if sul_document_type == Settings.sul_doc_types.inproceedings
	      conference_hash = {}
	      conference_hash[:startdate] = publication.xpath('ConferenceStartDate').text unless publication.xpath("ConferenceStartDate").blank?
	      conference_hash[:enddate] = publication.xpath('ConferenceEndDate').text unless publication.xpath("ConferenceEndDate").blank?
	      conference_hash[:city] = publication.xpath('ConferenceCity').text unless publication.xpath("ConferenceCity").blank?
	      conference_hash[:statecountry] = publication.xpath('ConferenceStateCountry').text unless publication.xpath("ConferenceStateCountry").blank?
	      record_as_hash[:conference] = conference_hash unless conference_hash.empty?

	    elsif sul_document_type == Settings.sul_doc_types.book
	      record_as_hash[:booktitle] = publication.xpath('PublicationSourceTitle').text unless publication.xpath("PublicationSourceTitle").blank?
	      record_as_hash[:pages] = publication.xpath('Pagination').text unless publication.xpath("Pagination").blank?
	      identifiers << {:type => 'doi', :id => publication.xpath('DOI').text, :url => 'http://dx.doi.org/' + publication.xpath('DOI').text} unless publication.xpath('DOI').blank?

	    end

	    if sul_document_type == Settings.sul_doc_types.article || (sul_document_type == Settings.sul_doc_types.inproceedings && ! publication.xpath('Issue').blank?)
	      journal_hash = {}
	      journal_hash[:name] = publication.xpath('PublicationSourceTitle').text unless publication.xpath('PublicationSourceTitle').blank?
	      journal_hash[:volume] = publication.xpath('Volume').text unless publication.xpath('Volume').blank?
	      journal_hash[:issue] = publication.xpath('Issue').text unless publication.xpath('Issue').blank?
	      journal_hash[:articlenumber] = publication.xpath('ArticleNumber').text unless publication.xpath('ArticleNumber').blank?
	      journal_hash[:pages] = publication.xpath('Pagination').text unless publication.xpath('Pagination').blank?
	      journal_identifiers = Array.new
	      journal_identifiers << {:type => 'issn', :id => publication.xpath('ISSN').text, :url => 'http://searchworks.stanford.edu/?search_field=advanced&number=' + publication.xpath('ISSN').text} unless publication.xpath('ISSN').blank?
	      journal_identifiers << {:type => 'doi', :id => publication.xpath('DOI').text, :url => 'http://dx.doi.org/' + publication.xpath('DOI').text} unless publication.xpath('DOI').blank?
	      journal_hash[:identifier] = journal_identifiers
	      record_as_hash[:journal] = journal_hash
	    end

	    unless issn.blank? || publication.xpath('Issue').blank? || sul_document_type == Settings.sul_doc_types.article
	        book_series_hash = {}
	        book_series_hash[:identifier] = [issn]
	        book_series_hash << publication.xpath('PublicationSourceTitle').text unless publication.xpath('PublicationSourceTitle').blank?
	        book_series_hash << publication.xpath('Volume').text unless publication.xpath('Volume').blank?
	        record_as_hash[:series] = book_series_hash
	    end
	    record_as_hash[:identifier] = identifiers
	    record_as_hash
	  end


	def self.lookup_sw_doc_type(doc_type_list)
	    if !(@@sw_conference_proceedings_type_strings & doc_type_list).empty?
	      type =  Settings.sul_doc_types.inproceedings
	    elsif !(@@sw_book_type_strings & doc_type_list).empty?
	      type =  Settings.sul_doc_types.book
	    else
	      type =  Settings.sul_doc_types.article
	    end
	    type
	end







end
