require 'dotiw'
require 'activerecord-import'
require "net/http"
require "json"
#require "always_verify_ssl_certificates"

namespace :cap do

	desc "poll cap for authorship information"
    task :poll_authorship => :environment do
    	
		#get_new_token
		get_authorship_data

		#auth = YAML.load(File.open('auth.yaml'))
		#auth={}
		#auth[:get_token_uri] = "***REMOVED***"
		#auth[:get_token_port] = 443
		#auth[:get_token_path] = "/oauth/token"
		#auth[:get_token_user] = "sul"
		#auth[:get_token_pass] = "***REMOVED***"
		#auth[:authorship_api_uri] = "irt-dev.stanford.edu"
		#auth[:authorship_api_path] = "/cap-api/api/cap/v1/authors"
  	end

  	def get_authorship_data
  		include ActionView::Helpers::DateHelper
		start_time = Time.now
		@cap_authorship_logger = Logger.new(Rails.root.join('log', 'cap_authorship_api.log'))
  		@cap_authorship_logger.info "Started authorship import " + DateTime.now.to_s
  		page_count = 0
  		@last_page = false
  		@total_running_count = 0
  		@no_sunetid_count = 0
  		@no_sunet_in_sul_count = 0
  		until @last_page
  			page_count += 1
  			process_next_batch_of_authorship_data(page_count, 1000)
  			puts (@total_running_count).to_s + " in " + distance_of_time_in_words_to_now(start_time, include_seconds = true)
  			@cap_authorship_logger.info @total_running_count.to_s + " records were processed in " + distance_of_time_in_words_to_now(start_time)

  			#if page_count === 3 then break end
  		end
  		puts page_count.to_s + " pages of 1000 records were processed in " + distance_of_time_in_words_to_now(start_time)
  		puts @total_running_count.to_s + " total records were processed in " + distance_of_time_in_words_to_now(start_time)
  		puts @no_sunetid_count.to_s + " cap records had no sunetids."
  		puts @no_sunet_in_sul_count.to_s + " cap records found no matching sunetid in sul records."
      	@cap_authorship_logger.info "Finished authorship import." + DateTime.now.to_s
      	@cap_authorship_logger.info @total_running_count.to_s + "records were processed in " + distance_of_time_in_words_to_now(start_time)
      	@cap_authorship_logger.info @no_sunetid_count.to_s + " records had no sunetids."
      	@cap_authorship_logger.info @no_sunet_in_sul_count.to_s + " cap records found no matching sunetid in sul records."
  	end

  
  	def process_next_batch_of_authorship_data(page_count, page_size)
  		begin
	  		auth = YAML.load(File.open(Rails.root.join('config', 'auth.yaml')))
			#AlwaysVerifySSLCertificates.ca_file = '/opt/local/share/curl/curl-ca-bundle.crt'
			http = Net::HTTP.new(auth[:authorship_api_uri_qa], auth[:authorship_api_port])	
			http.use_ssl = true
			http.verify_mode = OpenSSL::SSL::VERIFY_PEER
			#http.ca_file = '/opt/local/share/curl/curl-ca-bundle.crt'
		#	http.verify_mode = OpenSSL::SSL::VERIFY_PEER
			http.ssl_version = :SSLv3
			request = Net::HTTP::Get.new(auth[:authorship_api_path_qa] + "?p=" + page_count.to_s + "&ps=" + page_size.to_s)
			#puts "bearer " + auth[:token].to_s
			token = auth[:access_token]
			
			3.times do
				request["Authorization"] = "bearer " + token
				http.start
				response = http.request(request)

				if response.class == Net::HTTPUnauthorized 
					http.finish
					token = get_new_token
				elsif response.class == Net::HTTPInternalServerError
					http.finish
					puts "a server error: "
					puts response.body.to_s
					@last_page = true
					break
				else
					response_body = response.body
					the_response_as_hash = JSON.parse(response_body)
					process_batch(the_response_as_hash)
					http.finish
					break
				end
			end
			
		rescue => e
			puts e.message
			puts e.backtrace
			@cap_authorship_logger.info "Error: " + e.backtrace
		end
		@last_page
  	end

  	def process_batch(json_response)
  		#puts "in the process_batch"
  			if json_response["values"].blank?
  				puts "no values in json: " + json_response.to_s
  				# we return as though last page since we can't check.
  				@last_page = true
  			else
		  		#puts json_response.to_s
		  		json_response["values"].each do | record |
		  			@total_running_count += 1
		  			active = record["active"]
		  			email = record["profile"]["email"]
		  			sunetid = record["profile"]["uid"]
		  			cap_profile_id = record["profile"]["profileId"]
		  			if sunetid.blank?
		  				#puts " record seems to be missing sunet: " + record.to_s
		  				@cap_authorship_logger.info "Cap record missing sunet: " + record.to_s
		  				@no_sunetid_count += 1
		  			else
		  				author = Author.where(sunetid: sunetid).first 
		  				if author
		  					author.update_attributes(cap_profile_id: cap_profile_id, email: email, active_in_cap: active)
		  				else
		  					#puts "no such author for sunetid: " + sunetid 
		  					@cap_authorship_logger.info "no such author for sunetid: " + sunetid
		  					@no_sunet_in_sul_count += 1
		  				end
		  			end
		  			
		  		end
		  		@last_page = json_response["lastPage"]
  			end	
  	end

  	def get_new_token
  		puts "in the get_new_token"
  		auth = YAML.load(File.open(Rails.root.join('config', 'auth.yaml')))
  		http = Net::HTTP.new(auth[:get_token_uri], auth[:get_token_port])
		http.use_ssl = true
		http.verify_mode = OpenSSL::SSL::VERIFY_PEER
		http.ssl_version = :SSLv3
		request = Net::HTTP::Post.new(auth[:get_token_path])
		request.basic_auth(auth[:get_token_user], auth[:get_token_pass])
		request.set_form_data({"grant_type" => "client_credentials"})	
		http.start	   
		token = JSON.parse(http.request(request).body)["access_token"]
		auth[:access_token] = token.to_s
		puts "the token: " + token.to_s
		http.finish
		File.open(Rails.root.join('config', 'auth.yaml'), 'w') {|f| YAML.dump(auth, f)}
		puts token.to_s
		token.to_s
  	end

end
