require 'socket'
class CapHttpClient

  attr_reader :auth

  def initialize
    @base_timeout_retries = 3
    @base_timeout_period = 500
    @auth_token = generate_token
  end

  def generate_token
    http = Net::HTTP.new(ConfigSettings.CAP.TOKEN_URI, ConfigSettings.CAP.PORT)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_PEER
    request = Net::HTTP::Post.new(ConfigSettings.CAP.TOKEN_PATH)
    request.basic_auth(ConfigSettings.CAP.TOKEN_USER, ConfigSettings.CAP.TOKEN_PASS)
    request.set_form_data('grant_type' => 'client_credentials')
    http.start
    http.finish if http.started?
    JSON.parse(http.request(request).body)['access_token'].to_s
  rescue Timeout::Error => te
    timeout_retries -= 1
    if timeout_retries > 0
      # increase timeout
      timeout_period += 500
      retry
    else
      NotificationManager.handle_authorship_pull_error(te, "Timeout error on call to retrieve token for cap authorship feed - #{Time.zone.now}")
      raise
    end
  rescue => e
    NotificationManager.handle_authorship_pull_error(e, 'Problem with http call to cap authorship api')
    raise
  end

  def get_batch_from_cap_api(page_count, page_size, since = '')
    request_path = "#{ConfigSettings.CAP.AUTHORSHIP_API_PATH}?p=#{page_count}&ps=#{page_size}"
    request_path << "&since=#{since}" unless since.blank?
    make_cap_request(request_path)
  end

  def get_auth_profile(cap_profile_id)
    make_cap_request("#{ConfigSettings.CAP.AUTHORSHIP_API_PATH}/#{cap_profile_id}")
  end

  def get_cap_profile_by_sunetid(sunetid)
    make_cap_request("#{ConfigSettings.CAP.AUTHORSHIP_API_PATH}?uids=#{sunetid}")
  end

  private

  def make_cap_request(request_path)
    json_response = {}
    timeout_retries = @base_timeout_retries
    timeout_period = @base_timeout_period

    begin
      http = setup_cap_http
      request = Net::HTTP::Get.new(request_path)
      token = @auth_token

      3.times do
        request['Authorization'] = 'bearer ' + token
        http.start
        response = http.request(request)

        if response.class == Net::HTTPUnauthorized
          http.finish if http.started?
          token = generate_token
        elsif response.class == Net::HTTPInternalServerError
          http.finish
          response_body = response.body
          fail "Server error on authorship call - #{Time.zone.now} - message from server: #{response_body}"
        else
          response_body = response.body
          json_response = JSON.parse(response_body)
          http.finish if http.started?
        end
      end
    rescue Timeout::Error => te
      timeout_retries -= 1
      if timeout_retries > 0
        # increase timeout
        timeout_period += 500
        retry
      else
        NotificationManager.handle_harvest_problem(te, "Timeout error on authorship call - #{Time.zone.now}")
        raise
      end
    rescue => e
      NotificationManager.handle_harvest_problem(e, 'Problem with http call to cap authorship api')
      raise
    end
    json_response
  end

  def setup_cap_http
    http = Net::HTTP.new(ConfigSettings.CAP.AUTHORSHIP_API_URI, ConfigSettings.CAP.AUTHORSHIP_API_PORT)
    http.read_timeout = @base_timeout_period
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_PEER
    http
  end
end
