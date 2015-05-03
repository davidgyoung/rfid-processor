json.array!(@reader_events) do |reader_event|
  json.extract! reader_event, :id
  json.url reader_event_url(reader_event, format: :json)
end
