module WebOfScience

  # This class complements the WebOfScience::Harvester
  # Process records retrieved by any means; this is a progressive filtering of the harvested records to identify
  # those records that should create a new Publication.pub_hash, PublicationIdentifier(s) and Contribution(s).
  class ProcessRecords
    include WebOfScience::Contributions
    include WebOfScience::ProcessPubmed

    # @param author [Author]
    # @param records [WebOfScience::Records]
    def initialize(author, records)
      raise(ArgumentError, 'author must be an Author') unless author.is_a? Author
      raise(ArgumentError, 'records must be an WebOfScience::Records') unless records.is_a? WebOfScience::Records
      raise 'Nothing to do when Settings.WOS.ACCEPTED_DBS is empty' if Settings.WOS.ACCEPTED_DBS.empty?
      @author = author
      @records = records.select { |rec| Settings.WOS.ACCEPTED_DBS.include? rec.database }
    end

    # @return [Array<String>] WosUIDs that create a new Publication
    def execute
      return [] if records.empty?
      create_publications
    rescue StandardError => err
      NotificationManager.error(err, "Author: #{author.id}, ProcessRecords failed", self)
      []
    end

    private

      attr_reader :author
      attr_reader :records

      delegate :links_client, to: :WebOfScience

      # @return [Array<String>] WosUIDs that successfully create a new Publication or Contribution
      def create_publications
        return [] if records.empty?
        matching_uids = Publication.where(wos_uid: records.map(&:uid)).pluck(:wos_uid)
        save_wos_records(records.reject { |rec| matching_uids.include? rec.uid })
        records.select { |rec| !matching_contribution(author, rec) && create_publication(rec) }
               .map(&:uid)
               .uniq
      ensure
        pubmed_additions(records)
      end

      # Save and select new WebOfScienceSourceRecords
      # Note: add nothing to PublicationIdentifiers here, or filter_by_contributions might reject them
      # @param [Array<WebOfScience::Record>] recs
      # @return [Array<WebOfScienceSourceRecord>] created records
      def save_wos_records(recs)
        return if recs.empty?
        process_links
        batch = recs.map do |rec|
          attribs = { source_data: rec.to_xml }
          attribs[:doi] = rec.doi if rec.doi.present?
          attribs[:pmid] = rec.pmid if rec.pmid.present?
          attribs
        end
        WebOfScienceSourceRecord.create!(batch)
      end

      # @param [WebOfScience::Record] record
      # @return [Boolean] WebOfScience::Record created a new Publication?
      def create_publication(record)
        pub = Publication.create!(
          active: true,
          pub_hash: record.pub_hash,
          wos_uid: record.uid,
          pubhash_needs_update: true
        )
        contrib = find_or_create_contribution(author, pub)
        contrib.persisted?
      rescue StandardError => err
        message = "Author: #{author.id}, #{record.uid}; Publication or Contribution failed"
        NotificationManager.error(err, message, self)
        false
      end

      # WOS Links API methods
      # Integrate a batch of publication identifiers from the Links-API
      #
      # IMPORTANT: add nothing to PublicationIdentifiers here, or new_records will reject them
      # Note: the WebOfScienceSourceRecord is already saved, it could be updated with
      #       additional identifiers if there are fields defined for it.  Otherwise, these
      #       identifiers will get added to PublicationIdentifier after a Publication is created.
      # @return [void]
      def process_links
        links = retrieve_links
        records.each { |rec| rec.identifiers.update(links[rec.uid]) if rec.database == 'WOS' }
      rescue StandardError => err
        NotificationManager.error(err, "Author: #{author.id}, process_links failed", self)
      end

      # Retrieve a batch of publication identifiers for WOS records from the Links-API
      # @example {"WOS:000288663100014"=>{"pmid"=>"21253920", "doi"=>"10.1007/s12630-011-9462-1"}}
      # @return [Hash<String => Hash<String => String>>]
      def retrieve_links
        links_client.links records.map { |rec| rec.uid if rec.database == 'WOS' }.compact
      rescue StandardError => err
        NotificationManager.error(err, "Author: #{author.id}, retrieve_links failed", self)
      end
  end
end
