class AddPublicationIdentifierTypeAndValueIndex < ActiveRecord::Migration
  def change
    add_index :publication_identifiers, [:identifier_type, :identifier_value], name: 'pub_identifier_index_by_type_and_value'
  end
end
