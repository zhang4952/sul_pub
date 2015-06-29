class Author < ActiveRecord::Base
  acts_as_trashable

  has_many :contributions, :dependent => :destroy, :after_add => :contributions_changed_callback, :after_remove => :contributions_changed_callback do
    def build_or_update publication, contribution_hash = {}
      c = where(:publication_id => publication.id).first_or_initialize

      c.assign_attributes contribution_hash.merge(:publication_id => publication.id)
      if c.persisted?
        c.save
        publication.contributions_changed_callback
      else
        self << c
      end

      c
    end
  end

  # todo update the publication cached pubhash
  def contributions_changed_callback *args
  end

  has_many :publications, :through => :contributions do
  	def approved
  		where("contributions.status='approved'")
    end

    def with_sciencewire_id
      where(Publication.arel_table[:sciencewire_id].not_eq(nil))
    end
  end

  has_many  :approved_sw_ids, -> { where("contributions.status = 'approved'") }, :through => :contributions,
          :class_name => "PublicationIdentifier",
          :source => :publication_identifier,
          :foreign_key => "publication_id",
          :primary_key => "publication_id"

  has_many  :approved_publications, -> { where("contributions.status = 'approved'")}, :through => :contributions,
          :class_name => "Publication",
          :source => :publication


  #has_many :population_memberships, :dependent => :destroy
  #has_many :author_identifiers, :dependent => :destroy

  def update_from_cap_authorship_profile_hash(auth_hash)
    seed_hash = Author.build_attribute_hash_from_cap_profile(auth_hash)
    self.assign_attributes seed_hash
  end

  def Author.build_attribute_hash_from_cap_profile(auth_hash)
    # key/value not present in hash if value is not there
    # sunetid/ university id/ ca licence ---- at least one will be there
    seed_hash = {
      cap_profile_id: auth_hash['profileId'],
      active_in_cap:  auth_hash['active'],
      cap_import_enabled: auth_hash['importEnabled']
    }

    Author.add_to_hash_if_present(seed_hash, :sunetid, auth_hash['profile']['uid'])
    Author.add_to_hash_if_present(seed_hash, :university_id, auth_hash['profile']['universityId'])
    Author.add_to_hash_if_present(seed_hash, :email, auth_hash['profile']['email'])
    Author.add_to_hash_if_present(seed_hash, :emails_for_harvest, auth_hash['profile']['email'])
    Author.add_to_hash_if_present(seed_hash, :official_first_name, auth_hash['profile']['names']['legal']['firstName'])
    Author.add_to_hash_if_present(seed_hash, :official_middle_name, auth_hash['profile']['names']['legal']['middleName'])
    Author.add_to_hash_if_present(seed_hash, :official_last_name, auth_hash['profile']['names']['legal']['lastName'])
    Author.add_to_hash_if_present(seed_hash, :cap_first_name, auth_hash['profile']['names']['preferred']['firstName'])
    Author.add_to_hash_if_present(seed_hash, :cap_middle_name, auth_hash['profile']['names']['preferred']['middleName'])
    Author.add_to_hash_if_present(seed_hash, :cap_last_name, auth_hash['profile']['names']['preferred']['lastName'])
    Author.add_to_hash_if_present(seed_hash, :preferred_first_name, auth_hash['profile']['names']['preferred']['firstName'])
    Author.add_to_hash_if_present(seed_hash, :preferred_middle_name, auth_hash['profile']['names']['preferred']['middleName'])
    Author.add_to_hash_if_present(seed_hash, :preferred_last_name, auth_hash['profile']['names']['preferred']['lastName'])
    Author.add_to_hash_if_present(seed_hash, :california_physician_license, auth_hash['profile']['californiaPhysicianLicense'])
    seed_hash
  end

  def Author.add_to_hash_if_present(seed_hash, key, value)
    if(value.nil?)
      seed_hash[key] = ''
    else
      seed_hash[key] = value
    end
  end

  def Author.fetch_from_cap_and_create(profile_id)
    profile_hash = CapHttpClient.new.get_auth_profile(profile_id)
    a = Author.new
    a.update_from_cap_authorship_profile_hash(profile_hash)
    a.save!
    a
  end

  def harvestable?
    self.active_in_cap && self.cap_import_enabled
  end

end
