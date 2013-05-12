module SulBib

#validator for year

class YearCheck < Grape::Validations::Validator
  def validate_param!(attr_name, params)
    unless (1000..2100).include?(params[attr_name])
      throw :error, :status => 400, :message => "#{attr_name} must be four digits long and fall between 1000 and 2100"
    end
  end
end

#bibtex and bibjson parsers to parse incoming POSTs and PUTs
  module BibTexParser
    def self.call(object, env) 
        result = []
        bibtex_records =  
        bibtex_records.each do |record|   
          result << {title: record.title, 
                      year: record.year, 
                      publisher: record.publisher, 
                      authors: record.author}      
        end
        {:bib_list => result}
    end
  end

 module BibJSONParser
    def self.call(object, env) 
      {:pub_hash => JSON.parse(object)}
    end     
  end

  class API_schemas < Grape::API
    version 'v1', :using => :header, :vendor => 'sul', :format => :json
    format :json
    rescue_from :all, :backtrace => true
    
    get(:book) {IO.read(Rails.root.join('app', 'data', 'json_schemas', 'article.json')) }
    get(:article) { IO.read(Rails.root.join('app', 'data', 'json_schemas', 'book.json')) }
    get(:inproceedings) {IO.read(Rails.root.join('app', 'data', 'json_schemas', 'inproceedings.json')) }
   
  end

  class API_samples < Grape::API
    version 'v1', :using => :header, :vendor => 'sul', :format => :json
    format :json
    rescue_from :all, :backtrace => true
    
    get(:get_pub_out) {IO.read(Rails.root.join('app', 'data', 'api_samples', 'get_pub_out.json')) }
    get(:get_pubs_out) { IO.read(Rails.root.join('app', 'data', 'api_samples', 'get_pubs_out.json')) }
    get(:get_source_lookup_out) {IO.read(Rails.root.join('app', 'data', 'api_samples', 'get_source_lookup_out.json')) }
    get(:post_pub_in_json) {IO.read(Rails.root.join('app', 'data', 'api_samples', 'post_pub_in.json'))}
    get(:post_pub_in_bibtex) {IO.read(Rails.root.join('app', 'data', 'api_samples', 'post_pub_in.bibtex'))}
    get(:post_pub_out) {IO.read(Rails.root.join('app', 'data', 'api_samples', 'post_pub_out.json'))}
    get(:post_pubs_in) {IO.read(Rails.root.join('app', 'data', 'api_samples', 'post_pubs_in.json'))}
    get(:post_pubs_out) {IO.read(Rails.root.join('app', 'data', 'api_samples', 'post_pubs_out.json'))}
    get(:put_pub_in) {IO.read(Rails.root.join('app', 'data', 'api_samples', 'put_pub_in.json'))}
    get(:put_pub_out) {IO.read(Rails.root.join('app', 'data', 'api_samples', 'put_pub_out.json'))}
    get(:delete_pub_out) {IO.read(Rails.root.join('app', 'data', 'api_samples', 'delete_pub_out.json'))}
  end

  class API_authors < Grape::API
    version 'v1', :using => :header, :vendor => 'sul', :format => :json
    format :json
    get do
      error!('Unauthorized', 401) unless env['HTTP_CAPKEY'] == '***REMOVED***'
      Author.all(:include => :population_memberships, :conditions => "population_memberships.population_name = 'cap'")
    end
  end

  class API < Grape::API

    version 'v1', :using => :header, :vendor => 'sul', :cascade => false
    format :json
    #rescue_from :all, :backtrace => true
    
    #rescue_from :all do |e|
    #    rack_response({ :message => "rescued from #{e.class.name}" })
    #end

helpers do
  def wrap_as_bibjson_collection(description, query, records)
    {
        metadata: {
          _created: Time.now.iso8601,  
          description: description, 
          format: "BibJSON",  
          license: "some licence", 
          query: query, 
          records:  records.count.to_s 
        }, 
        records: records
    }
  end

  include Sciencewire
end


params do
  optional :year, type: Integer, :year_check => true, desc: "Four digit year."
  requires :title
  optional :source
end

get :sourcelookup do
    error!('Unauthorized', 401) unless env['HTTP_CAPKEY'] == '***REMOVED***'
      all_matching_records = []

      # set source to all sources if param value is blank     
      source = params[:source] || Settings.manual_source + '+' + Settings.sciencewire_source
      last_name = params[:lastname]
      first_name = params[:firstname]
      middle_name = params[:middlename]
      title = params[:title]
      year = params[:year]

      sources = source.split('+')

      if source.include?(Settings.sciencewire_source)
        sw_results = query_sciencewire_for_publication(first_name, last_name, middle_name, title, year)
        all_matching_records.push(*sw_results)
      end

      if source.include?(Settings.manual_source)
        query_hash = {}
        #query_hash[:last_name] = last_name unless last_name.empty? 
        #query_hash[:first_name] = first_name unless first_name.empty?
        #query_hash[:middle_name] = middle_name unless middle_name.empty?
        query_hash[:human_readable_title] = title unless title.blank?
        query_hash[:year] = year unless year.blank?
        query_hash[:is_active] = true
        query_hash[:is_local_only] = true  

        SourceRecord.where(query_hash).each { |source_record| all_matching_records << source_record.publication.pub_hash }
      end

      wrap_as_bibjson_collection("Search results from requested sources: " + source, env["ORIGINAL_FULLPATH"], all_matching_records)
    
    end

    get do
      error!('Unauthorized', 401) unless env['HTTP_CAPKEY'] == '***REMOVED***'
      matching_records = []
      population = params[:population] || Settings.cap_population_name
      changedSince = params[:changedSince] || "1000-01-01"
      capProfileId = params[:capProfileId]
      population.downcase!
      if capProfileId.blank?
        description = "Records for population '" + population + "' that have changed since " + changedSince
        Publication.find_each(
          :conditions => "publications.updated_at > '" + DateTime.parse(changedSince).to_s + "'"      
          #:include => :population_membership,
          #:conditions => "population_memberships.population_name = '" + population + "' AND publications.updated_at > '" + DateTime.parse(changedSince).to_s + "'"      
          ) do
            | publication | matching_records << publication.pub_hash
        end
      else
        author = Author.where(cap_profile_id: capProfileId).first
        if author.nil?
          description = "No results - user identifier doesn't exist in SUL system."
        else
          description = "All known publications for CAP profile id " + capProfileId
          matching_records = author.contributions.collect { |contr| contr.publication.pub_hash }
        end
      end
      wrap_as_bibjson_collection(description, env["ORIGINAL_FULLPATH"].to_s, matching_records)
    end

#With a parser, parsed data is available "as-is" in env['api.request.body']. 
#Without a parser, data is available "as-is" and in env['api.request.input'].

    content_type :json, "application/json"
    parser :json, BibJSONParser
    post do        
      error!('Unauthorized', 401) unless env['HTTP_CAPKEY'] == '***REMOVED***'    
      #request_body = env['api.request.body'] 
      request_body_unparsed = env['api.request.input']
      #puts "the body: " + request_body.to_s
      #puts "and unparsed: " + request_body_unparsed.to_s
      fingerprint = Digest::SHA2.hexdigest(request_body_unparsed)
      #puts "the fingerprint: " + fingerprint
      existingRecord = SourceRecord.where(source_fingerprint: fingerprint, source_name: Settings.manual_source).first
      unless existingRecord.nil?  
        header "Location", env["REQUEST_URI"] + "/" + existingRecord.publication_id.to_s
        error!('See Other - duplicate post', 303)     
      end
      pub = Publication.build_new_manual_publication(Settings.cap_provenance, params[:pub_hash], request_body_unparsed)
      header "Location", env["REQUEST_URI"].to_s + "/" + pub.id.to_s
      pub.pub_hash
    end


    content_type :json, "application/json"
    parser :json, BibJSONParser
    put ':id' do
      error!('Unauthorized', 401) unless env['HTTP_CAPKEY'] == '***REMOVED***'
      #the last known etag must be sent in the 'if-match' header, returning 412 “Precondition Failed” if etags don't match, 
      #and a 428 "Precondition Required" if the if-match header isn't supplied
      pub = Publication.find(params[:id])
      if pub.nil?
        error!({ "error" => "No such publication", "detail" => "You've requested a non-existant publication." }, 404)
      elsif pub.deleted 
        error!("Gone - old resource probably deleted.", 410)
      elsif pub.source_records.exists?(:is_local_only => false) 
        error!({ "error" => "This record may not be modified.  If you had originally entered details for the record, it has been superceded by a central record.", "detail" => "missing widget" }, 403)
      elsif request.env["HTTP_IF_MATCH"].blank?
        error!("Precondition Required", 428) 
      elsif request.env["HTTP_IF_MATCH"] != pub.updated_at
        error!("Precondition Failed", 412) 
      else
        pub.update_manual_pub_from_pub_hash(params[:pub_hash], Settings.cap_provenance)
        pub.pub_hash
      end
    end


    get ':id' do
      error!('Unauthorized', 401) unless env['HTTP_CAPKEY'] == '***REMOVED***'
      pub = Publication.find_by_id(params[:id])
      if pub.nil? 
        error!("Not Found", 404) 
      elsif pub.deleted 
        error!("Gone - old resource probably deleted.", 410)
      end
      pub.pub_hash
    end


    delete ':id' do
      error!('Unauthorized', 401) unless env['HTTP_CAPKEY'] == '***REMOVED***'
      pub = Publication.find(params[:id])
      pub.deleted = true
      pub.save
    end

  end
end

#monkey patch Grape to allow directly returning unescaped json string.
# TODO:  look at instead returning this as a hash, which
# grape would then serialize.
=begin
 module Grape
  module Formatter
    module Json
      class << self
        def call(object, env)
          return object if ! object || object.is_a?(String)
          return object.to_json if object.respond_to?(:to_json)
          raise Grape::Exceptions::InvalidFormatter.new(object.class, 'json')
        end
      end
    end
  end
end
=end