require 'okcomputer'

OkComputer.mount_at = 'status' # use /status or /status/all or /status/<name-of-check>
OkComputer.check_in_parallel = true

# Simple echo of the VERSION file
class VersionCheck < OkComputer::AppVersionCheck
  def version
    File.read(Rails.root.join('VERSION')).chomp
  rescue Errno::ENOENT
    raise UnknownRevision
  end
end
OkComputer::Registry.register 'version', VersionCheck.new

class DelegateCheck < OkComputer::Check
  attr_reader :delegate
  def initialize(delegate)
    @delegate = delegate
  end
  def check
    if delegate.working?
      mark_message 'working'
    else
      mark_failure
      mark_message 'not working'
    end
  rescue => e
    mark_failure
    mark_message "#{e.class.name} received: #{e.message}"
  end
end

# delegate to the clients to see if they are working
clients = [
  Cap::Client,
  PubmedClient
]
clients << ScienceWireClient if Settings.SCIENCEWIRE.enabled
if Settings.WOS.enabled
  clients << WebOfScience
  clients << Clarivate::LinksClient
end
clients.each do |klass|
  OkComputer::Registry.register "external-#{klass.name}", DelegateCheck.new(klass)
end

# check models to see if at least they have some data
class TablesHaveDataCheck < OkComputer::Check
  def check
    msg = ""
    [
      Author,
      BatchUploadedSourceRecord,
      Contribution,
      Publication,
      PublicationIdentifier,
      PubmedSourceRecord,
      SciencewireSourceRecord,
      UserSubmittedSourceRecord
    ].each do |klass|
      begin
        # has at least one record and use select(:id) to avoid returning all data
        if klass.select(:id).first!.present?
          msg += "#{klass.name} has data. "
        else
          mark_failure
          msg += "#{klass.name} has no data. "
        end
      rescue ActiveRecord::RecordNotFound
        mark_failure
        msg += "#{klass.name} has no data. "
      rescue => e
        mark_failure
        msg += "#{e.class.name} received: #{e.message}. "
      end
    end
    mark_message msg
  end
end
OkComputer::Registry.register "feature-tables-have-data", TablesHaveDataCheck.new

class WosHitsRecentlyCheck < OkComputer::Check
  def clause
    3.weeks.ago
  end

  def check
    count = WebOfScienceSourceRecord.where("updated_at > ?", clause).count
    mark_message "#{count} WoS records updated since #{clause}.  "
    mark_failure if count.zero?
  end
end
OkComputer::Registry.register "wos-records-harvested-recently", WosHitsRecentlyCheck.new

class DelayedJobCheck < OkComputer::Check
  def check
    status = `RAILS_ENV=#{Rails.env} bundle exec bin/delayed_job status`
    result = $?.success?
    mark_failure unless result && status.include?('running')
  end
end
OkComputer::Registry.register 'delayed-job-running', DelayedJobCheck.new
