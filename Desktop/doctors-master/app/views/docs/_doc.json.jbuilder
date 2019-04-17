json.extract! doc, :id, :name, :specialty, :zip, :review, :created_at, :updated_at
json.url doc_url(doc, format: :json)
