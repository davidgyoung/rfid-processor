json.array!(@readers) do |reader|
  json.extract! reader, :id
  json.url reader_url(reader, format: :json)
end
