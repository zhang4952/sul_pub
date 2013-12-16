require 'parallel'


class Finder

  def fix(pub)
    return unless(pub.sciencewire_id)

    h = pub.pub_hash
    return unless(h[:documentcategory_sw] =~ /^Conference Proceeding Document/i)

    if( h[:type] =~ /^article/i)
      @found += 1
      @logger.info "Fixing #{pub.id}"
      h[:type] = Settings.sul_doc_types.inproceedings
      pub.pub_hash = h
      pub.sync_publication_hash_and_db
      pub.save
    end

  rescue => e
    @logger.error "Problem with pub #{pub.id}: #{e.inspect}"
    @logger.error e.backtrace.join "\n"
  end

  def setup_log
    @logger = Logger.new(Rails.root.join('log', "fix_procs_marked_as_article_#{Process.pid}.log"))
    @logger.formatter = proc { |severity, datetime, progname, msg|
      "#{severity} #{datetime}[#{Process.pid}]: #{msg}\n"
    }
    @logger.info "Started search"
  end

  def search
    last_id = Publication.last.id

    batch_count = 3
    batch_size = (last_id/batch_count).to_i
    batch_1 = [] << 1 << batch_size
    batch_2 = [] << (batch_size + 1) << (2*batch_size)
    batch_3 = [] << (2*batch_size + 1) << last_id
    sacks = [] << batch_1 << batch_2 << batch_3
    Parallel.each(sacks, :in_processes => 3) do |sack|
      @found = 0
      setup_log
      ActiveRecord::Base.connection.reconnect!
      ActiveRecord::Base.logger.level = 1
      count = 0
      start_key = sack[0]
      stop_key = sack[1]
      query = Publication.where(Publication.arel_table[Publication.primary_key].gteq(start_key)).
                          where(Publication.arel_table[Publication.primary_key].lteq(stop_key))
      query.find_each do |pub|
        count += 1
        fix(pub)
        if(count % 1000 == 0)
          @logger.info "Processed #{count}"
        end
      end
      @logger.info "Done. Processed #{count}"
      @logger.info "Found #{@found}"
    end


  end

end

r = Finder.new
r.search