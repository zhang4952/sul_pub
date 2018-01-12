module Csl

  class RoleMapper

    class << self

      # Parse authors
      def authors(pub_hash)
        return [] if pub_hash[:author].blank?
        authors = pub_hash[:author]
        case pub_hash[:provenance].to_s.downcase
        when 'batch'
          # This is from BibtexIngester.convert_bibtex_record_to_pub_hash
          Csl::BibtexMapper.authors_to_csl(authors)
        when 'cap'
          # This is a CAP manual submission
          Csl::CapMapper.authors_to_csl(authors)
        when 'pubmed'
          # This is a PubMed publication and the author is created in
          # PubmedSourceRecord.convert_pubmed_publication_doc_to_hash
          Csl::PubmedMapper.authors_to_csl(authors)
        when 'sciencewire'
          # This is a ScienceWire publication and the author is created in
          # SciencewireSourceRecord.convert_sw_publication_doc_to_hash
          Csl::SciencewireMapper.authors_to_csl(authors)
        else
          parse_authors(authors)
        end
      end

      # Parse editors for various provenance data:
      def editors(pub_hash)
        return [] if pub_hash[:author].blank?
        authors = pub_hash[:author]
        case pub_hash[:provenance].to_s.downcase
        when 'batch', 'pubmed', 'sciencewire'
          # This is from BibtexIngester.convert_bibtex_record_to_pub_hash
          [] # there are no editors
        when 'cap'
          # This is a CAP manual submission
          Csl::CapMapper.editors_to_csl(authors)
        else
          parse_editors(authors)
        end
      end

      private

        def parse_authors(pub_hash_authors)
          # All the pub_hash[:author] data is assumed be an editor or an author and
          # the only way to tell is when the editor has role=='editor'
          authors = pub_hash_authors.reject { |a| a[:role].to_s.downcase.include?('editor') }
          if authors.length > 5
            # we pass the first five authors and the very last author because some
            # formats add the very last name when using et-al. the CSL should drop the sixth name if unused.
            # We could in fact pass all the author names to the CSL processor and let it
            # just take the first five, but that seemed to crash the processor for publications
            # with a lot of authors (e.g, 2000 authors)
            authors = authors[0..4] << authors.last
            #   authors << { :name => "et al." }
            # elsif pub_hash[:etal]
            #   authors = pub_hash[:author].collect { |a| a }
            #   authors << { :name => "et al." }
          end
          authors.map { |author| parse_author_name(author) }.compact
        end

        def parse_editors(pub_hash_authors)
          # All the pub_hash[:author] data is assumed be an editor or an author and
          # the only way to tell is when the editor has role=='editor'
          editors = pub_hash_authors.select { |a| a[:role].to_s.downcase.include?('editor') }
          editors.map { |editor| parse_author_name(editor) }.compact
        end

        # Extract { 'family' => last_name, 'given' => rest_of_name } or
        # return nil if the the family name is blank.
        # @return [Hash<String => String>|nil]
        def parse_author_name(author)
          family_name = parse_family_name(author)
          return nil if family_name.blank?
          given_names = parse_given_names(author)
          { 'family' => family_name, 'given' => given_names }
        end

        # Generic extraction of family name
        # @return [String, nil]
        def parse_family_name(author)
          last_name = author[:lastname]
          last_name = author[:name].split(',').first.strip if last_name.blank? && author[:name].present?
          last_name.present? ? last_name : nil
        end

        # Generic extraction of given name
        # Use parsed name parts, if available.  Otherwise use :name, if available.
        # Add period after single character (initials).
        # @return [String, nil]
        def parse_given_names(author)
          given_names = ''
          %i(firstname middlename).map { |k| author[k] }.reject(&:blank?).each do |name_part|
            given_names << ' ' << name_part
            given_names << '.' if name_part =~ /^[[:upper:]]$/
          end
          if given_names.blank? && author[:name].present?
            names = author[:name].split(',').map(&:strip)
            names.shift # drop the last name
            names.reject(&:blank?).each do |name_part|
              given_names << ' ' << name_part
              given_names << '.' if name_part =~ /^[[:upper:]]$/
            end
          end
          given_names.present? ? given_names.strip : nil
        end
    end
  end
end

