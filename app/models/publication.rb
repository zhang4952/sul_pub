class Publication < ActiveRecord::Base
  acts_as_trashable

  before_save :sync_publication_hash_and_db, if: proc { |pub| pub.pubhash_needs_update? }

  after_create do
    set_sul_pub_id_in_hash
    save
  end

  # we actually do query these columns in
  # create_or_update_pub_and_contribution_with_harvested_sw_doc
  # :title,
  # :year,
  # :issn,
  # :pages,
  # :publication_type

  before_save do
    self.title = pub_hash[:title] unless pub_hash[:title].blank?
    self.issn = pub_hash[:issn] unless pub_hash[:issn].blank?
    self.pages = pub_hash[:pages] unless pub_hash[:pages].blank?
    self.publication_type = pub_hash[:type] unless pub_hash[:type].blank?
    self.year = pub_hash[:year] unless pub_hash[:year].blank?
  end

  has_many :contributions, autosave: true, dependent: :destroy, after_add: :contributions_changed_callback, after_remove: :contributions_changed_callback do
    def for_author(a)
      where(author_id: a.id)
    end

    def build_or_update(author, contribution_hash = {})
      c = where(author_id: author.id).first_or_initialize

      c.assign_attributes contribution_hash.merge(author_id: author.id)
      if c.persisted?
        c.save
        proxy_association.owner.contributions_changed_callback
      else
        self << c
      end

      c
    end
  end

  has_many :authors, autosave: true, through: :contributions, after_add: :contributions_changed_callback, after_remove: :contributions_changed_callback
  has_many :publication_identifiers, autosave: true, dependent: :destroy, after_add: :identifiers_changed_callback, after_remove: :identifiers_changed_callback do
    def with_type(t)
      where(identifier_type: t)
    end
  end
  has_many :user_submitted_source_records
  has_one :batch_uploaded_source_record

  def contributions_changed_callback(*_args)
    pubhash_needs_update!
    true
  end

  def identifiers_changed_callback(*_args)
    pubhash_needs_update!
    true
  end

  serialize :pub_hash, Hash

  def self.updated_after(date)
    where('publications.updated_at > ?', date)
  end

  def self.with_active_author
    ids = joins(:authors).where('authors.active_in_cap' => true).select('publications.id').uniq.pluck(:id)
    Publication.unscoped.where(id: ids)
  end

  def self.find_or_create_by_pmid(pmid)
    Publication.find_by_pmid(pmid) || SciencewireSourceRecord.get_pub_by_pmid(pmid) || PubmedSourceRecord.get_pub_by_pmid(pmid)
  end

  def self.find_or_create_by_sciencewire_id(sw_id)
    Publication.find_by_sciencewire_id(sw_id) || SciencewireSourceRecord.get_pub_by_sciencewire_id(sw_id)
  end

  def self.find_by_doi(doi)
    PublicationIdentifier.where(identifier_type: 'doi', identifier_value: doi).map(&:publication)
  end

  def self.find_by_pmid_in_pub_id_table(pmid)
    PublicationIdentifier.where(identifier_type: 'pmid', identifier_value: pmid).map(&:publication)
  end

  def self.build_new_manual_publication(provenance, pub_hash, original_source_string)
    existingRecord = UserSubmittedSourceRecord.find_or_initialize_by_source_data(original_source_string)

    if existingRecord && existingRecord.publication
      fail ActiveRecord::RecordNotUnique.new('Publication for user submitted source record already exists', nil)
    end

    pub = Publication.new(
      active: true,
      pub_hash: pub_hash
    )

    pub.update_manual_pub_from_pub_hash(pub_hash, provenance, original_source_string)

    pub
  end

  def update_manual_pub_from_pub_hash(incoming_pub_hash, provenance, original_source_string)
    incoming_pub_hash[:provenance] = provenance
    self.pub_hash = incoming_pub_hash.dup
    r = user_submitted_source_records.first || UserSubmittedSourceRecord.find_or_initialize_by_source_data(original_source_string)
    r.assign_attributes(
      is_active: true,
      source_data: original_source_string,
      title: title,
      year: year
    )

    if r.new_record?
      self.user_submitted_source_records = [r]
    else
      r.save
    end

    update_any_new_contribution_info_in_pub_hash_to_db
    pubhash_needs_update! if persisted?
    self
  end

  def build_from_sciencewire_hash(new_sw_pub_hash)
    self.pub_hash = new_sw_pub_hash

    self.sciencewire_id = new_sw_pub_hash[:sw_id]

    unless pmid.blank?
      new_sw_pub_hash[:pmid] = pmid.to_s # Preserve the pmid just in case incoming sciencewire doc doesn't have PMID
      add_any_pubmed_data_to_hash
    end

    self
  end

  def build_from_pubmed_hash(new_pubmed_pub_hash)
    self.pub_hash = new_pubmed_pub_hash
    self
  end

  # this is a very temporary method to be used only for the initial import
  # of data from CAP.
  def cutover_sync_hash_and_db
    set_sul_pub_id_in_hash
    pub_hash[:last_updated] = updated_at.to_s
    add_all_db_contributions_to_my_pub_hash
    # add identifiers that are in the hash to the pub identifiers db table
    pub_hash[:identifier].each do |identifier|
      publication_identifiers.create(
        identifier_type: identifier[:type],
        certainty: 'confirmed',
        identifier_value: identifier[:id],
        identifier_uri: identifier[:url])
    end
    update_formatted_citations
    self
  end

  def sync_publication_hash_and_db
    set_last_updated_value_in_hash

    add_all_db_contributions_to_my_pub_hash

    sync_identifiers_in_pub_hash_to_db
    add_all_identifiers_in_db_to_pub_hash
    set_sul_pub_id_in_hash if persisted?

    update_formatted_citations
    @pubhash_needs_update = false
    self
  end

  def rebuild_pub_hash
    if sciencewire_id
      sw_source_record = SciencewireSourceRecord.find_by_sciencewire_id(sciencewire_id)
      build_from_sciencewire_hash(sw_source_record.source_as_hash)
    elsif pmid
      pubmed_source_record = PubmedSourceRecord.find_by_pmid(pmid)
      build_from_pubmed_hash(pubmed_source_record.source_as_hash)
    end
    sync_publication_hash_and_db

    self
  end

  def sync_identifiers_in_pub_hash_to_db
    incoming_types = Array(pub_hash[:identifier]).map { |id| id[:type] }
    publication_identifiers.each do |id|
      next if id.identifier_type =~ /^legacy_cap_pub_id$/i   # Do not delete legacy_cap_pub_id
      id.delete unless incoming_types.include? id.identifier_type
    end

    Array(pub_hash[:identifier]).each do |identifier|
      next if identifier[:type] =~ /^SULPubId$/i

      i = publication_identifiers.find { |x| x.identifier_type == identifier[:type] } || PublicationIdentifier.new

      i.assign_attributes certainty: 'confirmed',
                          identifier_type: identifier[:type],
                          identifier_value: identifier[:id],
                          identifier_uri: identifier[:url]

      if i.persisted?
        i.save
      else
        publication_identifiers << i
      end
    end
  end

  def update_any_new_contribution_info_in_pub_hash_to_db
    Array(pub_hash[:authorship]).each do |contrib|
      hash_for_update = {
        status: contrib[:status],
        visibility: contrib[:visibility],
        featured: contrib[:featured]
      }

      sul_author_id = contrib[:sul_author_id]

      author = if sul_author_id
                 Author.find(sul_author_id)
               elsif contrib[:cap_profile_id]
                 Author.find_by_cap_profile_id(contrib[:cap_profile_id])
               end

      # todo??
      next if author.nil?

      hash_for_update[:author_id] = author.id
      cap_profile_id = author.cap_profile_id
      hash_for_update[:cap_profile_id] = cap_profile_id unless cap_profile_id.blank?
      contrib = contributions.for_author(author).first_or_initialize
      contrib.assign_attributes(hash_for_update)

      if contrib.persisted?
        contrib.save
      else
        contributions << contrib
      end
    end
    true
  end

  def delete!
    self.deleted = true
    save
  end

  def deleted?
    deleted
  end

  def pubhash_needs_update!(*_args)
    @pubhash_needs_update = true
  end

  def pubhash_needs_update?
    @pubhash_needs_update || false
  end

  ###
  # Methods for manipulating the pub_hash data to sync db state => cached pub hash
  ###

  def rebuild_authorship
    add_all_db_contributions_to_my_pub_hash
    set_last_updated_value_in_hash
  end

  def add_any_pubmed_data_to_hash
    return if pmid.blank?
    pubmed_hash = PubmedSourceRecord.get_pubmed_hash_for_pmid(pmid)
    return if pubmed_hash.nil?

    pub_hash[:mesh_headings] = pubmed_hash[:mesh_headings] unless pubmed_hash[:mesh_headings].blank?
    pub_hash[:abstract] = pubmed_hash[:abstract] unless pubmed_hash[:abstract].blank?
  end

  def set_last_updated_value_in_hash
    pub_hash[:last_updated] = Time.zone.now.to_s
  end

  def set_sul_pub_id_in_hash
    sul_pub_id = id.to_s
    pub_hash[:sulpubid] = sul_pub_id
    pub_hash[:identifier] ||= []
    pub_hash[:identifier] << { type: 'SULPubId', id: sul_pub_id, url: 'http://sulcap.stanford.edu/publications/' + sul_pub_id }
  end

  def add_all_identifiers_in_db_to_pub_hash
    pub_hash[:identifier] ||= []
    publication_identifiers.reload if persisted?
    pub_hash[:identifier] = publication_identifiers.collect do |identifier|
      ident_hash = {}
      ident_hash[:type] = identifier.identifier_type unless identifier.identifier_type.blank?
      ident_hash[:id] = identifier.identifier_value unless identifier.identifier_value.blank?
      ident_hash[:url] = identifier.identifier_uri unless identifier.identifier_uri.blank?
      ident_hash
    end
  end

  def add_all_db_contributions_to_my_pub_hash
    pub_hash[:authorship] = contributions.map(&:to_pub_hash) if pub_hash
  # elsif self.pub_hash && ! self.pub_hash[:authorship]
  #  Logger.new(Rails.root.join('log', 'publications_errors.log')).info("No authorship entry in pub_hash for " + self.id.to_s)
  # else
  #  Logger.new(Rails.root.join('log', 'publications_errors.log')).info("No pub hash for " + self.id.to_s)
  # end
  rescue => e
    Rails.logger.info "some problem with hash: #{pub_hash}"
    pub_logger = Logger.new(Rails.root.join('log', 'contributions_publications_errors.log'))
    pub_logger.error "some problem with adding contributions to the hash for pub #{id}"
    pub_logger.error "the hash: #{pub_hash}"
    pub_logger.error e.message
    pub_logger.error e.backtrace
  end

  def update_formatted_citations
    h = PubHash.new(pub_hash)

    pub_hash[:apa_citation] = h.to_apa_citation
    pub_hash[:mla_citation] = h.to_mla_citation
    pub_hash[:chicago_citation] = h.to_chicago_citation
  end

  ##
  #  Pubhash accessors
  ##
  def title
    pub_hash[:title]
  end

  def issn
    pub_hash[:issn]
  end

  def pages
    pub_hash[:pages]
  end

  def publication_type
    pub_hash[:type]
  end

  def year
    pub_hash[:year]
  end

  def sciencewire_pub?
    (pub_hash[:provenance] && pub_hash[:provenance] =~ /sciencewire/i) ? true : false
  end

  def pubmed_pub?
    (pub_hash[:provenance] && pub_hash[:provenance] =~ /pubmed/i) ? true : false
  end

  def authoritative_pmid_source?
    pubmed_pub? || sciencewire_pub?
  end

  alias_method :authoritative_doi_source?, :sciencewire_pub?
end
