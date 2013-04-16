
require 'sul_pub'

# puts "-u#{db_config['username']} -p#{db_config['password']} #{db_config['database']}"

namespace :cap do
  desc "ingest exising cap data"
  task :ingest => :environment do
    include SulPub
    include ActionView::Helpers::DateHelper
    #db_config = Rails.application.config.database_configuration[Rails.env]
    pmids = []
    contribs = {}
    # Publication.delete_all
    # Contribution.delete_all
    # AuthorIdentifier.delete_all
    # PublicationIdentifier.delete_all
    # SourceRecord.delete_all
    # Author.delete_all
    # PopulationMembership.delete_all
    client = Mysql2::Client.new(:host => "localhost", :username => "cap", :password => "cap", :database => "cap", :encoding => "utf8")
    results = client.query("select cap_old_publication.pubmed_id,
      cap_old_faculty_publication.faculty_id, 
      cap_old_faculty_publication.status
      from cap_old_faculty_publication join cap_old_publication 
      on cap_old_faculty_publication.publication_id = cap_old_publication.publication_id  
      where pubmed_id != 0 order by pubmed_id limit 200")

    # to run in batches of 5000:  limit 0,5000  then:  limit 5000,5000 then limit 10000,5000 then 15000,5000 etc.
    start_time = Time.now
    total_running_count = 0;

    #results = [] << {"pubmed_id"=>211, "faculty_id"=>10884, "status"=>"denied"}
    results.each do |row|
      
      pmid = row['pubmed_id'].to_s
      pmids << pmid
      contribs[pmid] = row

      if pmids.count == 200
        create_new_pubs_and_contributions_for_pmids(pmids, contribs)
        pmids.clear
        puts (total_running_count += 200).to_s + " in " + distance_of_time_in_words_to_now(start_time, include_seconds = true)
      end
    end

  end
end
