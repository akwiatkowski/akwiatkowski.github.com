class @BlogLive
  constructor: ->
  
  # run everything
  start: () ->
    $.ajax
      url: "/payload.json"
      success: (data) =>
        @data = data
        @startMap()
        
  startMap: () ->
    $("#content").height(600)
    $("#content").width(900)
    
    geojsonObject = {}
    vectorSource = new ol.source.Vector(features: (new ol.format.GeoJSON()).readFeatures(geojsonObject))
    
    for post in @data["posts"]
      if post["coords"]
        console.log post
        vectorSource.addFeature new ol.Feature(
          new ol.geom.Circle( 
            ol.proj.transform([
              post["coords"][1],
              post["coords"][0]],
            'EPSG:4326', 'EPSG:3857'),
            parseFloat(post["range"]) * 1000.0
            )
          )
    
    style = new ol.style.Style(
      stroke: new ol.style.Stroke(
        color: "#FF0000"
        width: 2
      )
      fill: new ol.style.Fill(color: "rgba(255, 0, 0, 0.2)")
    )
    
    vectorLayer = new ol.layer.Vector(
      source: vectorSource,
      style: style
    )
    
    map = new ol.Map(
      target: "content"
      projection: "EPSG:4326"
      layers: [
        new ol.layer.Tile({source: new ol.source.OSM()}),
        vectorLayer
      ]
      view: new ol.View(
        center: ol.proj.transform([19.4553, 51.7768], 'EPSG:4326', 'EPSG:3857'),
        zoom: 6
      )
    )
