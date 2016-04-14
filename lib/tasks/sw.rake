namespace :sw do
  def harvester
    @harvester ||= begin
      h = ScienceWireHarvester.new

      Signal.trap('USR1') do
        harvester.debug = true
      end

      h
    end
  end

  # rake sw:fortnightly_harvest[1, 5]
  desc 'harvest from sciencewire by email or known sciencewire pub ids'
  task :fortnightly_harvest, [:starting_author_id, :ending_author_id] => :environment do |_t, args|
    args.with_defaults(starting_author_id: 1, ending_author_id: -1)
    starting_author_id = (args[:starting_author_id]).to_i
    ending_author_id = (args[:ending_author_id]).to_i
    harvester.harvest_pubs_for_all_authors(starting_author_id, ending_author_id)
    # CapAuthorshipMailer.welcome_email("harvest complete").deliver
  end

  desc 'harvest (with multiple processes) from sciencewire by email or known sciencewire pub ids'
  task parallel_harvest: :environment do
    harvester.harvest_pubs_for_all_authors_parallel
  end

  desc 'Harvest high priority faculty using the name-only query'
  task :faculty_harvest, [:path_to_ids] => :environment do |_t, args|
    harvester.use_middle_name = false
    ids = IO.readlines(args[:path_to_ids]).map(&:strip)
    harvester.harvest_pubs_for_author_ids ids
  end

  desc 'Harvest for a cap_profile_id using the name-only query'
  task :cap_profile_harvest, [:cap_profile_id] => :environment do |_t, args|
    harvester.use_middle_name = false
    cap_profile_id = (args[:cap_profile_id]).to_i
    author = Author.where(cap_profile_id: cap_profile_id).first
    author ||= Author.fetch_from_cap_and_create(cap_profile_id)
    harvester.harvest_pubs_for_author_ids author.id
    # Summarize the publications harvested
    pubs = Contribution.where(author_id: author.id).map {|c| c.publication }
    pubs.each {|p| puts "publication #{p.id}: #{p.pub_hash[:apa_citation]}"}
  end

  desc 'Harvest using a directory full of Web Of Science bibtex query results'
  task :wos_harvest, [:path_to_bibtex] => :environment do |_t, args|
    harvester.harvest_from_directory_of_wos_id_files args[:path_to_bibtex]
  end

  desc 'Harvest for a given sunetid and a json-file with an array of WoS ids'
  task :wos_sunetid_json, [:sunetid, :path_to_json] => :environment do |_t, args|
    harvester.harvest_for_sunetid_with_wos_json args[:sunetid], args[:path_to_json]
  end

  desc 'Harvest using a text report file of WOS ids and cap_profile_ids'
  task :wos_profile_id_report, [:path_to_report] => :environment do |_t, args|
    harvester.harvest_from_wos_id_cap_profile_id_report args[:path_to_report]
  end
end
