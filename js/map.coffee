class @BlogMap
  constructor: ->

  # run everything
  start: () ->
    $.ajax
      url: "/payload.json"
      success: (data) =>
        @data = data
        @initializeLayout()
        @startMap()

  initializeLayout: () ->
    clientHeight = document.body.clientHeight
    containerWidth = $(".container").width()
    topPosition = $("#map-container").position().top

    mapHeight = clientHeight - topPosition - 200
    if mapHeight < 300
      mapHeight = 300

    $('.intro-header').height( clientHeight )
    $("#map-container").width( containerWidth )

    $("#content").height( mapHeight )
    $("#content").width( containerWidth )


  startMap: () ->
    styleLineRegular = new ol.style.Style(
      stroke: new ol.style.Stroke(
        color: "#008800"
        width: 3
      )
      fill: new ol.style.Fill(color: "rgba(255, 0, 0, 0.2)")
    )
    styleLineHike = new ol.style.Style(
      stroke: new ol.style.Stroke(
        color: "#ff9900"
        width: 3
      )
      fill: new ol.style.Fill(color: "rgba(255, 0, 0, 0.2)")
    )
    styleLineCycle = new ol.style.Style(
      stroke: new ol.style.Stroke(
        color: "#0055FF"
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
    sourceLinesCycle = new ol.source.Vector(features: (new ol.format.GeoJSON()).readFeatures(geojsonObject))
    sourceLinesHike = new ol.source.Vector(features: (new ol.format.GeoJSON()).readFeatures(geojsonObject))
    sourceLinesRegular = new ol.source.Vector(features: (new ol.format.GeoJSON()).readFeatures(geojsonObject))

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

      if post["coords"]
        for route in post["coords"]
          if route["route"]
            console.log route

            coords = []
            for c in route["route"]
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

            if route["type"] == "hike"
              sourceLinesHike.addFeature(feature)
            else if route["type"] == "bicycle"
              sourceLinesCycle.addFeature(feature)
            else if route["type"] == "car"
              sourceLinesRegular.addFeature(feature)
            else if route["type"] == "train"
              sourceLinesRegular.addFeature(feature)
            else
              sourceLinesRegular.addFeature(feature)

    circleLayer = new ol.layer.Vector(
      source: sourceCircles,
      style: styleCircle
    )

    lineLayerCycle = new ol.layer.Vector(
      source: sourceLinesCycle,
      style: styleLineCycle
    )
    lineLayerHike = new ol.layer.Vector(
      source: sourceLinesHike,
      style: styleLineHike
    )
    lineLayerRegular = new ol.layer.Vector(
      source: sourceLinesRegular,
      style: styleLineRegular
    )

    map = new ol.Map(
      target: "content"
      projection: "EPSG:4326"
      layers: [
        new ol.layer.Tile({source: new ol.source.OSM()}),
        circleLayer,
        lineLayerRegular,
        lineLayerHike,
        lineLayerCycle
      ]
      view: new ol.View(
        center: ol.proj.transform([19.4553, 51.7768], 'EPSG:4326', 'EPSG:3857'),
        zoom: 6
      )
    )

    interaction = new ol.interaction.Select()
    interaction.getFeatures().on "add", (e) =>
      last_p = null
      for obj in e.target.b
        p = obj.B
        last_p = p

        $("#links").html("")

        $("<a>",
          text: p["post-date"] + " - " + p["post-title"]
          title: p["post-date"] + " - " + p["post-title"]
          href: p["post-url"]
        ).appendTo "#links"

      for post in @data["posts"]
        if post.url == last_p["post-url"]
          new_image = post["header-ext-img"]

          if new_image
            img = new Image()
            img.onload = =>
              $('#background2').css('background-image', $('#background1').css('background-image' ) )
              $('#background2').show()
              $('#background1').css('background-image', "url(" + new_image + ")")
              $("#background2").fadeOut 1500, =>
              console.log("done")

          img.src = new_image

    map.addInteraction( interaction )
