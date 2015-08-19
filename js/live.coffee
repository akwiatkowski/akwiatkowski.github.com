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
    
    styleLine = new ol.style.Style(
      stroke: new ol.style.Stroke(
        color: "#FF0000"
        width: 3
      )
      fill: new ol.style.Fill(color: "rgba(255, 0, 0, 0.2)")
    )
    styleCircle = new ol.style.Style(
      stroke: new ol.style.Stroke(
        color: "#FF0000"
        width: 3
      )
      fill: new ol.style.Fill(color: "rgba(255, 0, 0, 0.2)")
    )      
    
    geojsonObject = {}
    sourceCircles = new ol.source.Vector(features: (new ol.format.GeoJSON()).readFeatures(geojsonObject))
    sourceLines = new ol.source.Vector(features: (new ol.format.GeoJSON()).readFeatures(geojsonObject))
    
    for post in @data["posts"]
      if false #post["coords-circle"]
        sourceCircles.addFeature new ol.Feature(
          new ol.geom.Circle( 
            ol.proj.transform([
              post["coords-circle"][1],
              post["coords-circle"][0]],
            'EPSG:4326', 'EPSG:3857'),
            parseFloat(post["range"]) * 1000.0
            )
          )

      if false # post["coords-from"]
        coords = [
          ol.proj.transform([
            post["coords-from"][1],
            post["coords-from"][0]],
          'EPSG:4326', 'EPSG:3857'),
            
          ol.proj.transform([
            post["coords-to"][1],
            post["coords-to"][0]],
          'EPSG:4326', 'EPSG:3857')
        ]
        
        sourceLines.addFeature new ol.Feature(
          new ol.geom.LineString(coords)
        )  

      if post["coords-multi"]
        coords = []
        for c in post["coords-multi"]
          ct = ol.proj.transform([
            c[1],
            c[0]],
          'EPSG:4326', 'EPSG:3857')
          coords.push ct
        
        feature = new ol.Feature(
          new ol.geom.LineString(coords)
        )
        
        feature.set("post-date", post["date"])
        feature.set("post-url", post["url"])
        feature.set("post-title", post["title"])
        
        sourceLines.addFeature(feature)
        
    
    
    circleLayer = new ol.layer.Vector(
      source: sourceCircles,
      style: styleCircle
    )

    lineLayer = new ol.layer.Vector(
      source: sourceLines,
      style: styleLine
    )
    
    map = new ol.Map(
      target: "content"
      projection: "EPSG:4326"
      layers: [
        new ol.layer.Tile({source: new ol.source.OSM()}),
        circleLayer,
        lineLayer
      ]
      view: new ol.View(
        center: ol.proj.transform([19.4553, 51.7768], 'EPSG:4326', 'EPSG:3857'),
        zoom: 6
      )
    )

    interaction = new ol.interaction.Select()
    interaction.getFeatures().on "add", (e) => 
      for obj in e.target.b
        p = obj.B
        
        $("#links").html("")
        
        $("<a>",
          text: p["post-date"] + " - " + p["post-title"]
          title: p["post-date"] + " - " + p["post-title"]
          href: p["post-url"]
        ).appendTo "#links"
               

    map.addInteraction( interaction )


