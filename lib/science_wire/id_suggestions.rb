module ScienceWire
  # Facade class for creating an Array of ScienceWire suggestion ID's
  class IdSuggestions
    attr_reader :client

    def initialize(client:)
      @client = client
    end

    # @param [ScienceWire::AuthorAttributes] author_attributes
    # @return [Array<Integer>]
    def id_suggestions(author_attributes)
      journal_suggestions(author_attributes) + conference_suggestions(author_attributes)
    end

    # @param [ScienceWire::AuthorAttributes] author_attributes
    # @return [Array<Integer>]
    def journal_suggestions(author_attributes)
      suggestions(ScienceWire::Query::JournalDocumentSuggestion.new(author_attributes))
    end

    # @param [ScienceWire::AuthorAttributes] author_attributes
    # @return [Array<Integer>]
    def conference_suggestions(author_attributes)
      suggestions(ScienceWire::Query::ConferenceProceedingDocumentSuggestion.new(author_attributes))
    end

    private

      # @return [Array<Integer>]
      def suggestions(query)
        client.matched_publication_item_ids_for_author_and_parse(
          query.generate
        )
      end
  end
end
