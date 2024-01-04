require "../data/src/services/map/downloader"

[16].each do |zoom|
  m = Map::Downloader.new(
    lat_from: 49.20723805555556,
    lat_to: 54.703875000000004,
    lon_from: 14.110069444444443,
    lon_to: 23.88176388888889,
    zoom: zoom,
    overwrite: false
  )

  m.make_it_so
end
