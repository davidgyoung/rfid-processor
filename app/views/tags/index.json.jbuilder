json.array!(@tags) do |tag|
  json.extract! tag, :id, :tag_id, :rssi, :antenna, :last_seen_at, :funded, :member
  json.url tag_url(tag, format: :json)
end
