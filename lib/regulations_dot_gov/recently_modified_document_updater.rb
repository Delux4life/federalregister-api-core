class RegulationsDotGov::RecentlyModifiedDocumentUpdater
  extend Memoist
  include CacheUtils
  
  class MissingDocumentNumber < StandardError; end
  class NoDocumentFound < StandardError; end

  DOCUMENT_TYPE_IDENTIFIERS = ['PR', 'FR', 'N']
  
  attr_reader :days
  
  def initialize(days)
    @days = days
  end

  def perform
    ActiveRecord::Base.verify_active_connections!
    EntryObserver.disabled = true
    current_time           = Time.current
    expire_cache           = false

    updated_documents.each do |updated_document|
      if updated_document.federal_register_document_number.nil?
        notify_missing_document_number(updated_document)
        next 
      end
      
      entry = Entry.find_by_document_number(updated_document.federal_register_document_number)

      if entry
        entry.regulations_dot_gov_docket_id = updated_document.docket_id
        update_docket = entry.regulations_dot_gov_docket_id_changed? && entry.regulations_dot_gov_docket_id.present?

        if updated_document.document_id
          entry.comment_url = updated_document.comment_url
          entry.regulationsdotgov_url = updated_document.url
        end

        if entry.changed?
          expire_cache = true
        end
        entry.checked_regulationsdotgov_at = current_time

        entry.save!

        if update_docket
          Resque.enqueue(DocketImporter, entry.regulations_dot_gov_docket_id)
        end
      else
        notify_missing_document(updated_document)
      end
    end

    if expire_cache
      purge_cache("/api/v1/*")
    end
  end

  private

  def notify_missing_document(document)
    Honeybadger.notify(
      error_class: NoDocumentFound,
      error_message: "Regulations Dot Gov returned document #{document.federal_register_document_number} as changed within the last #{days} days, but no document was found.  Document details: #{document.raw_attributes}"
    )
  end

  def notify_missing_document_number(document)
    Honeybadger.notify(
      error_class: MissingDocumentNumber,
      error_message: "Regulations Dot Gov returned document without a federal_register_document_number as changed within the last #{days} days.  Document details: #{document.raw_attributes}"
    )
  end

  def updated_documents
    Array.new.tap do |collection|
      DOCUMENT_TYPE_IDENTIFIERS.each do |document_type_identifier|
        client = RegulationsDotGov::Client.new
        documents = client.find_documents_updated_within(days, document_type_identifier)

        collection << documents
      end
    end.flatten
  end
  memoize :updated_documents

end
