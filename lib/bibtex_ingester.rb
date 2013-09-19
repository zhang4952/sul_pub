require 'bibtex'
require 'citeproc'
require 'dotiw'

class BibtexIngester
  @@book_type_mapping = ['book', 'booklet', 'inbook', 'incollection', 'manual', 'techreport']
  @@article_type_mapping = ['article', 'misc', 'unpublished']
  @@inproceedings_type_mapping = ['conference', 'proceedings', 'inproceedings']

  def ingest_from_source_directory(directory)
    @batch_dir = directory || '/Users/jameschartrand/Documents/OSS/projects/stanford-cap/bibtex_import_files'
  #  puts "the dir is set #{@batch_dir}"
    @bibtex_import_logger = Logger.new(Rails.root.join('log', 'bibtext_import.log'))
    @bibtex_import_logger.info "Started bibtext import #{DateTime.now}"
    @total_records_processed = 0
    @matches_on_issn_count = 0
    @matches_on_title_count = 0
    @total_duplicates = 0
    @total_faulty_record_count = 0
    @total_successfully_ingested = 0
    @missing_sunet_id_count = 0
    @records_without_sunet_id = 0
    @bad_file_error_count = 0
    @good_file_count = 0
    @total_deduped_count = 0
    @total_new_pubs = 0
    @batch_source_records_created_count = 0
    @unidentified_pub_type_count = 0
      Dir.open(@batch_dir).each do | batch_dir_name |
        next if batch_dir_name == '.' or batch_dir_name == '..'
        batch_dir_full_path = "#{@batch_dir}/#{batch_dir_name}"
        if File.directory? batch_dir_full_path
          Dir.open(batch_dir_full_path).each do | bibtex_file_name |
           # sunet_id = File.basename(bibtex_file_name, '.*')
            next if batch_dir_name == '.' or batch_dir_name == '..'

            file_full_path = "#{batch_dir_full_path}/#{bibtex_file_name}"
            log_file_full_path = "#{batch_dir_full_path}/#{bibtex_file_name}_import.log"
            next if File.directory? file_full_path or bibtex_file_name == '.DS_Store' or bibtex_file_name.end_with?('.log')
            @record_count_for_file = 0
            @errors_for_file = 0
            @ingested_for_file = 0

            @bibtex_file_logger = Logger.new(log_file_full_path)
            @bibtex_file_logger.info "Started bibtext import for file #{DateTime.now}"

            process_bibtex_file(file_full_path, batch_dir_name, bibtex_file_name)

            @bibtex_file_logger.info "Ended bibtext import for file #{DateTime.now}"
            @bibtex_file_logger.info "#{@record_count_for_file} records processed."
            @bibtex_file_logger.info "#{@ingested_for_file} records were successfully ingested."
            @bibtex_file_logger.info "#{@errors_for_file} records had problems and weren't ingested."
         #   puts "#{@count_for_file} records processed for file: #{bibtex_file_name}"

          end
        end
      end
      @bibtex_import_logger.info "Finished bibtex import #{DateTime.now}"
      @bibtex_import_logger.info "#{@bad_file_error_count} files couldn't be parsed at all."
      @bibtex_import_logger.info "#{@good_file_count} files were parsed."
      @bibtex_import_logger.info "#{@missing_sunet_id_count} files containing #{@records_without_sunet_id} records weren't parsed because the sunet id wasn't found in the db."



      @bibtex_import_logger.info "#{@total_records_processed} records processed for import."
      @bibtex_import_logger.info "#{@total_successfully_ingested} records were ingested or were duplicates."
      @bibtex_import_logger.info "#{@total_faulty_record_count} records weren't ingested or weren't duplicates."
      @bibtex_import_logger.info "#{@unidentified_pub_type_count} records weren't ingested because their pub type wasn't identified."

      @bibtex_import_logger.info "#{@batch_source_records_created_count} batch_source_records were created."
      @bibtex_import_logger.info "#{@total_duplicates} were duplicates from prior batch."

      @bibtex_import_logger.info "#{@matches_on_issn_count} matched existing sw or pubmed pubs by issn."
      @bibtex_import_logger.info "#{@matches_on_title_count} matched existing existing sw or pubmed pubs by title."
      @bibtex_import_logger.info "#{@total_deduped_count} total records were deduplicated against sw or pubmed pubs."
      @bibtex_import_logger.info "#{@total_new_pubs} new publication records were created."

    #  puts "#{@total_records_processed} records processed for import."
  end

  def process_bibtex_file(file_full_path, batch_name, bibtex_file_name)

    sunet_id = File.basename(bibtex_file_name, '.*')

    author = Author.where(sunetid: sunet_id).first
    if author.nil?
      puts "no author found for sunetid: #{sunet_id}"
      @missing_sunet_id_count += 1
      @bibtex_import_logger.info "Couldn't find an author for sunetid: #{sunet_id}"
      @bibtex_file_logger.info "Couldn't find an author for sunetid: #{sunet_id}"
       begin
        @records_without_sunet_id += BibTeX.open(file_full_path).count

      rescue => e
        @bad_file_error_count += 1
        @bibtex_import_logger.error "Couldn't open the bibtex file anyhow, #{bibtex_file_name}, at all: "
        @bibtex_import_logger.error e.message
        @bibtex_file_logger.error e.message
        @bibtex_file_logger.error e.backtrace
      end
    else
      begin
        records = BibTeX.open(file_full_path)
      rescue => e
        puts "some error in the rescue"
        @bibtex_import_logger.error "Couldn't open the bibtex file, #{bibtex_file_name}, at all: "
        @bibtex_import_logger.error "See the log file for #{sunet_id} for details."
        @bibtex_import_logger.error e.message
        @bibtex_file_logger.error "Couldn't open the bibtex file at all: "
        @bibtex_file_logger.error e.message
        @bibtex_file_logger.error e.backtrace
        @bad_file_error_count += 1
      end
      if records && ! records.empty?
        @good_file_count += 1
        records.each do | record |
            @record_count_for_file += 1
            @total_records_processed += 1
            process_record(record, author)
        end
      else
        "puts no records for file: #{bibtex_file_name}"
        @bibtex_import_logger.error "puts no records for file: #{bibtex_file_name}"
      end
    end
  end

  def process_record(record, author)
    pub = nil

    source_attrib_hash = {
        is_active: true,
        sunet_id: author.sunetid,
        successful_import: true,
        bibtex_source_data: record.to_s
    }
    unless record["title"].blank? then source_attrib_hash[:title] =  record.title.to_s end
    unless record["year"].blank? then source_attrib_hash[:year] =  record.year.to_s end

    begin
      existing_source_record = BatchUploadedSourceRecord.where(sunet_id: author.sunetid, title: record.title.to_s).first

    rescue => e
      @bibtex_import_logger.info "Search for existing batch upload for : #{record.to_s} failed probably because of unicode issue."
      @bibtex_import_logger.info "Error: #{e.message}"
    end
    if ! existing_source_record.nil?
        pub = existing_source_record.publication
        @total_duplicates +=1
        # if the publication has been updated with a sw or pubmed record since it was first submitted, then do nothing
        if (pub.sciencewire_id.blank?) && (pub.pmid.blank?)
          pub.update_attributes(active: true, pub_hash: convert_bibtex_record_to_pub_hash(record, author))
          existing_source_record.update_attributes(source_attrib_hash)
          existing_source_record.save
        end
    elsif ! determine_sul_pub_type(record.type.to_s.strip).nil?
      pub = find_existing_pub(record)
      if pub.nil?


        pub = Publication.create(active: true, pub_hash: convert_bibtex_record_to_pub_hash(record, author))
        @total_new_pubs += 1
      #  puts pub.to_yaml
      #  PublicationIdentifier.where(
      #                      :publication_id => pub.id,
      #                      :identifier_type => 'SULPubId').
      #            first_or_create(
      #                      :certainty => 'confirmed',
      #                      :identifier_type => 'SULPubId',
      #                      :identifier_value => pub.id,
      #                      :identifier_uri => "http://sulcap.stanford.edu/publications/#{pub.id}")
      end
      BatchUploadedSourceRecord.create(publication_id: pub.id).update_attributes(source_attrib_hash)
      @batch_source_records_created_count += 1
      # create the contribution regardless of whether we created a new pub or are using an existing pub
      Contribution.where(
                    author_id: author.id,
                    publication_id: pub.id).
                  first_or_create(
                    cap_profile_id: author.cap_profile_id,
                    status: "approved",
                    visibility: "private",
                    featured: false)
      #have to sync the pub hash to update new information, including new authorship
      pub.sync_publication_hash_and_db
      pub.save
    else
      @unidentified_pub_type_count += 1
      @bibtex_import_logger.info "No pub type for: #{record.to_s}"
    end
    @ingested_for_file += 1
    @total_successfully_ingested += 1

  rescue => e
    #puts e.message
    #puts e.backtrace
    @bibtex_import_logger.info "Record not ingested: #{record.to_s}"
    @bibtex_import_logger.info "Error: #{e.message}"
    @total_faulty_record_count += 1
  end


  def find_existing_pub(record)
    pub = nil
    issn = record["issn"].to_s || record["ISSN"].to_s
    pages = record["pages"].to_s
    year = record["year"].to_s
    title = record["title"].to_s

    if !issn.blank? && !pages.blank? && !year.blank?
      begin
        pub = Publication.where("(sciencewire_id is not null OR pmid is not null)
              AND issn =? AND pages=? AND year=? ", issn, pages, year).first
      rescue => e
        @bibtex_import_logger.info "Search for existing sw or pubmed pub for : #{record.to_s} failed probably because of unicode issue."
        @bibtex_import_logger.info "Error: #{e.message}"
      end
      if pub
        @matches_on_issn_count += 1
      end
    end
    if pub.nil? && !title.blank? && !pages.blank? && !year.blank?
      begin
        pub = Publication.where("(sciencewire_id is not null OR pmid is not null)
              AND title= ? AND year= ? AND pages= ? ", title, year, pages).first
      rescue => e
        @bibtex_import_logger.info "Search for existing sw or pubmed pub for : #{record.to_s} failed probably because of unicode issue."
        @bibtex_import_logger.info "Error: #{e.message}"
      end

      if pub
        @matches_on_title_count += 1
      end
    end
    if pub then @total_deduped_count += 1 end
    pub
  end

  def convert_bibtex_record_to_pub_hash(record, author)
    sul_document_type = determine_sul_pub_type(record.type.to_s.strip)

    record_as_hash = Hash.new
    identifiers = Array.new
    issn = record["issn"].to_s.strip unless record["issn"].blank?
    isbn = record["isbn"].to_s.strip unless record["isbn"].blank?
    doi = record["doi"].to_s.strip unless record["doi"].blank?

    unless issn.blank?
      issn_for_id_array = {:type => 'issn', :id => issn, :url => 'http://searchworks.stanford.edu/?search_field=advanced&number=' + issn}
      record_as_hash[:issn] = issn
    end
    unless isbn.blank?
      isbn_for_id_array = {:type => 'isbn', :id => isbn, :url => 'http://searchworks.stanford.edu/?search_field=advanced&number=' + isbn}
      record_as_hash[:isbn] = isbn
      identifiers << isbn_for_id_array
    end
    unless doi.blank?
      doi_for_id_array = {:type => 'doi', :id => doi, :url => 'http://dx.doi.org/' + doi}
      identifiers << doi_for_id_array
      record_as_hash[:doi] = doi
    end


    authorship_hash = {
      sul_author_id: author.id,
      status: 'approved',
      visibility: 'public',
      featured: false}
    unless author.cap_profile_id.blank?  then authorship_hash[:cap_profile_id] = author.cap_profile_id end

    record_as_hash[:authorship] = [ authorship_hash ]

    record_as_hash[:provenance] = Settings.batch_source
    unless record["title"].blank? then record_as_hash[:title] = record.title.to_s.strip end
    #unless !record["title"].blank && record["title"].blank? then record_as_hash[:title] = record.chapter.to_s.strip end
    unless record["booktitle"].blank? then record_as_hash[:booktitle] = record.booktitle.to_s.strip end
    unless record["author"].blank?
     record_as_hash[:author] = record.author.collect { |author| {:name => author.to_s} }
     record_as_hash[:allAuthors] = record.author.to_a.join(', ')
    end

    unless record["editor"].blank? then record_as_hash[:editor] = record.editor.to_s.strip end
    unless record["publisher"].blank? then record_as_hash[:publisher] =  record.publisher.to_s.strip end
    unless record["year"].blank? then record_as_hash[:year] = record.year.to_s.strip end
    unless record["address"].blank? then record_as_hash[:address] = record.address.to_s.strip end
    unless record["howpublished"].blank? then record_as_hash[:howpublished] = record.howpublished.to_s.strip end
    unless record["edition"].blank? then record_as_hash[:edition] = record.edition.to_s.strip end
    unless record["chapter"].blank? then record_as_hash[:chapter] = record.chapter.to_s.strip end


    record_as_hash[:type] = sul_document_type
    record_as_hash[:bibtex_type] = record.type.to_s.strip

     if sul_document_type == Settings.sul_doc_types.inproceedings
      unless record["organization"].blank? then conference_hash = {organization: record["organization"].to_s.strip} end
      unless conference_hash.nil? then record_as_hash[:conference] = conference_hash end
    end

    if sul_document_type == Settings.sul_doc_types.article || ! record.journal.blank?
      journal_hash = {}
      unless record["journal"].blank? then journal_hash[:name] = record.journal.to_s.strip end
      unless record["volume"].blank? then journal_hash[:volume] = record.volume.to_s.strip end
      unless record["issue"].blank? then journal_hash[:issue] = record.issue.to_s.strip end
      unless record["number"].blank? then journal_hash[:articlenumber] = record.number.to_s.strip end
      unless record["pages"].blank? then journal_hash[:pages] = record.pages.to_s.strip end
      unless record["month"].blank? then journal_hash[:month] = record.month.to_s.strip end
      journal_identifiers = Array.new
      unless issn.blank? then journal_identifiers << issn_for_id_array end

    journal_hash[:identifier] = journal_identifiers
    unless journal_hash.empty? then record_as_hash[:journal] = journal_hash end
    elsif
       # if this is an article then the pages go in the article object, but if not put it in the main object.
      unless record["pages"].blank? then record_as_hash[:pages] = record.pages.to_s.strip  end
    end

    unless ! record["series"]
        book_series_hash = {}
        book_series_hash[:identifier] = [issn_for_id_array]
        unless record["series"].blank? then book_series_hash[:title] = record.series.to_s.strip  end
        unless record["volume"].blank? then book_series_hash[:volume] = record.volume.to_s.strip end
        unless record["month"].blank? then book_series_hash[:month] = record.month.to_s.strip end
        unless book_series_hash.empty? then record_as_hash[:series] = book_series_hash  end
    end
    record_as_hash[:identifier] = identifiers
    record_as_hash


  end

  def determine_sul_pub_type(bibtex_type)
    if @@book_type_mapping.include?(bibtex_type)
      Settings.sul_doc_types.book
    elsif @@article_type_mapping.include?(bibtex_type)
      Settings.sul_doc_types.article
    elsif @@inproceedings_type_mapping.include?(bibtex_type)
      Settings.sul_doc_types.inproceedings
    else
      nil
    end
  end


end

