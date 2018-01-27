module WebOfScience

  # This class complements the WebOfScience::Harvester
  # Process records retrieved by any means; this is a progressive filtering of the harvested records to identify
  # those records that should create a new Publication.pub_hash, PublicationIdentifier(s) and Contribution(s).
  class ProcessRecords
    include WebOfScience::Contributions

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
      message = "Author: #{author.id}, ProcessRecords failed"
      NotificationManager.error(err, message, self)
      []
    end

    private

      attr_reader :author
      attr_reader :records

      delegate :links_client, to: :WebOfScience

      # ----
      # Record filters and data flow steps
      # - this is a progressive reduction of the number of records processed, given
      #   application logic for the de-duplication of new records.

      # @return [Array<String>] WosUIDs that create a new Publication
      def create_publications
        select_new_wos_records # cf. WebOfScienceSourceRecord
        save_wos_records # save WebOfScienceSourceRecord
        filter_by_contributions # Contributions by PublicationIdentifier
        records.select! { |rec| create_publication(rec) }
        pubmed_additions
        records.map(&:uid)
      end

      # Filter and select new WebOfScienceSourceRecords
      def select_new_wos_records
        return if records.empty?
        matching_uids = WebOfScienceSourceRecord.where(uid: records.map(&:uid)).pluck(:uid)
        records.reject! { |rec| matching_uids.include? rec.uid }
      end

      # Save and select new WebOfScienceSourceRecords
      # Note: add nothing to PublicationIdentifiers here, or filter_by_contributions might reject them
      def save_wos_records
        return if records.empty?
        process_links
        records.select! do |rec|
          attr = { source_data: rec.to_xml }
          attr[:doi] = rec.doi if rec.doi.present?
          attr[:pmid] = rec.pmid if rec.pmid.present?
          WebOfScienceSourceRecord.new(attr).save!
        end
      end

      # Select records that have no contributions, based on matching PublicationIdentifiers
      # Note: must use unique identifiers, don't use ISSN or similar series level identifiers
      def filter_by_contributions
        records.reject! do |rec|
          contribution_by_identifier?(author, 'WosUID', rec.uid) ||
            contribution_by_identifier?(author, 'WosItemID', rec.wos_item_id) ||
            contribution_by_identifier?(author, 'doi', rec.doi) ||
            contribution_by_identifier?(author, 'pmid', rec.pmid)
        end
      end

      # @param [WebOfScience::Record] record
      # @return [Boolean] WebOfScience::Record created a new Publication?
      def create_publication(record)
        pub = Publication.new(
          active: true,
          pub_hash: record.pub_hash,
          wos_uid: record.uid
        )
        pub.pubhash_needs_update!
        pub.save!
        contrib = find_or_create_contribution(author, pub)
        contrib.persisted?
      rescue StandardError => err
        message = "Author: #{author.id}, #{record.uid}; Publication or Contribution failed"
        NotificationManager.error(err, message, self)
        false
      end

      # ----
      # PubMed

      # For WOS-records with a PMID, try to enhance them with PubMed data
      def pubmed_additions
        records.each { |rec| pubmed_addition(rec) }
      end

      # For WOS-record that has a PMID, fetch data from PubMed and enhance the pub.pub_hash with PubMed data
      # @param [WebOfScience::Record] record
      # @return [void]
      def pubmed_addition(record)
        return if record.pmid.blank?
        pub = Publication.find_by(wos_uid: record.uid)
        pub.pmid = record.pmid
        pub.save
        return if record.database == 'MEDLINE'
        pubmed_record = PubmedSourceRecord.for_pmid(record.pmid)
        pub.pub_hash.reverse_update(pubmed_record.source_as_hash)
        pub.save
      rescue StandardError => err
        message = "Author: #{author.id}, #{record.uid}, PubmedSourceRecord failed, PMID: #{record.pmid}"
        NotificationManager.error(err, message, self)
      end

      # ----
      # WOS Links API methods

      # Integrate a batch of publication identifiers from the Links-API
      #
      # IMPORTANT: add nothing to PublicationIdentifiers here, or new_records will reject them
      # Note: the WebOfScienceSourceRecord is already saved, it could be updated with
      #       additional identifiers if there are fields defined for it.  Otherwise, these
      #       identifiers will get added to PublicationIdentifier after a Publication is created.
      #
      # @return [void]
      def process_links
        links = retrieve_links
        records.each { |rec| update_links(rec, links[rec.uid]) }
      rescue StandardError => err
        message = "Author: #{author.id}, process_links failed"
        NotificationManager.error(err, message, self)
      end

      # Retrieve a batch of publication identifiers for WOS records from the Links-API
      # @example {"WOS:000288663100014"=>{"pmid"=>"21253920", "doi"=>"10.1007/s12630-011-9462-1"}}
      # @return [Hash<String => Hash<String => String>>]
      def retrieve_links
        uids = records.map { |rec| rec.uid if rec.database == 'WOS' }.compact
        links_client.links uids
      rescue StandardError => err
        message = "Author: #{author.id}, retrieve_links failed"
        NotificationManager.error(err, message, self)
      end

      # @param record [WebOfScience::Record]
      # @param links [Hash<String => String>] other identifiers (from Links API)
      # @return [void]
      def update_links(record, links)
        return unless record.database == 'WOS'
        record.identifiers.update links
      rescue StandardError => err
        message = "Author: #{author.id}, #{record.uid}, update_links failed"
        NotificationManager.error(err, message, self)
      end

  end
end
