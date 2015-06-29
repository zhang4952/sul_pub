Rails.configuration.middleware.use(IsItWorking::Handler) do |h|
  # Check the ActiveRecord database connection without spawning a new thread
  h.check :active_record, async: false

  h.check :cap do |status|
    begin
      CapHttpClient.new.get_batch_from_cap_api(1, 1)
      status.ok('CAP client active')
    rescue
      status.info('unable to connect to CAP')
    end
  end

  h.check :version do |status|
    begin
      ver = IO.read(Rails.root.join('VERSION')).strip
      status.info(ver)
    rescue
      status.info('unable to read version number')
    end
  end
end
