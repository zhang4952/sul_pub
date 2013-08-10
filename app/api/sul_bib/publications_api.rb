module SulBib
  class PublicationsAPI < Grape::API

    version 'v1', :using => :header, :vendor => 'sul', :cascade => false
    default_format :json

    helpers do

      def validate_or_create_author(auth_hash)
        return true if(Contribution.valid_authorship_hash?(auth_hash))

        cap_profile_id = auth_hash.first[:cap_profile_id]
        
        return false if(cap_profile_id.blank?)

        # The author does not exist in our system, but we have a cap_profile_id.
        # Try to create a new Author using the cap_profile_id
        Author.fetch_from_cap_and_create(cap_profile_id)
        true
      end
    end

    desc "CALL TO ADD A NEW MANUAL PUBLICATION"
    content_type :json, "application/json"
    parser :json, BibJSONParser
    params do
      requires :pub_hash
    end
    post do
      request_body_unparsed = env['api.request.input']
      logger.info("adding new manual publication from BibJSON")
      logger.debug("#{request_body_unparsed}")
      pub_hash = params[:pub_hash]
     # Rails.logger.debug "Incoming bibjson post attributes hash: #{pub_hash}"
      fingerprint = Digest::SHA2.hexdigest(request_body_unparsed)
      existingRecord = UserSubmittedSourceRecord.where(source_fingerprint: fingerprint).first
      if existingRecord
        logger.info("Found existing record for #{fingerprint}: #{existingRecord.inspect}; redirecting.")
          # the GRAPE redirect method issues a 303 (when original request is not a get, and a 302 for a get)
          # and sets the location header to the specified url
          # So, this next lines return 303 with location equal to the pub's uri
          redirect env["REQUEST_URI"] + "/" + existingRecord.publication_id.to_s
      else
        if pub_hash[:authorship].nil? || ! validate_or_create_author(params[:pub_hash][:authorship])
          error!("You haven't supplied a valid authorship record.", 406)
        end
        pub = Publication.build_new_manual_publication(Settings.cap_provenance, pub_hash, request_body_unparsed)
        pub.save
        pub.reload
        logger.debug("Created new publication #{pub.inspect}")
        header "Location", env["REQUEST_URI"].to_s + "/" + pub.id.to_s
        pub.pub_hash
      end
    end

    desc "CALL TO UPDATE A NEW MANUAL PUBLICATION"
    content_type :json, "application/json"
    parser :json, BibJSONParser
    params do
      requires :id
      requires :pub_hash
    end
    put ':id' do
      #the last known etag must be sent in the 'if-match' header, returning 412 “Precondition Failed” if etags don't match,
      #and a 428 "Precondition Required" if the if-match header isn't supplied
      
      begin
        pub = Publication.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        error!({ "error" => "No such publication", "detail" => "You've requested a non-existant publication." }, 404)
      end

      case 
        when pub.deleted?
          error!("Gone - old resource probably deleted.", 410)
        when (!pub.sciencewire_id.blank?) || (!pub.pmid.blank?)
          error!({ "error" => "This record may not be modified.  If you had originally entered details for the record, it has been superceded by a central record.", "detail" => "missing widget" }, 403)
        when env["HTTP_IF_MATCH"].blank?
          error!("Precondition Required", 428)
        when env["HTTP_IF_MATCH"] != pub.pub_hash[:last_updated]
          error!("Precondition Failed", 412)
        when params[:pub_hash][:authorship].nil? || ! Contribution.valid_authorship_hash?(params[:pub_hash][:authorship])
          error!("You haven't supplied a valid authorship record.", 406)      
      end

      original_source = env['api.request.input']
      logger.info("Update manual publication #{pub.inspect} with BibJSON")
      logger.debug("#{original_source}")

      pub.update_manual_pub_from_pub_hash(params[:pub_hash], Settings.cap_provenance, original_source)
      pub.save
      pub.reload
      logger.debug("resulting pub hash: #{pub.pub_hash}")
      pub.pub_hash
    end

    desc "GET A SINGLE RECORD"
    params do
      requires :id
    end
    get ':id' do
      begin
        pub = Publication.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        error!({ "error" => "No such publication", "detail" => "You've requested a non-existant publication." }, 404)
      end
      
      if pub.deleted?
        error!("Gone - old resource probably deleted.", 410)
      end
      
      pub.pub_hash
    end

    desc "MARK A RECORD AS DELETED"
    params do
      requires :id
    end
    delete ':id' do
      pub = Publication.find(params[:id])
      pub.delete!
    end

  end

end