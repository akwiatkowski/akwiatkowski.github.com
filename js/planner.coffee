class @BlogPlanner
  constructor: ->

  # run everything
  start: () ->
    @lands_posts = {}
    @lands = []
    @land_outputs = []

    $.ajax
      url: "/payload.json"
      success: (data) =>
        @data = data
        @processLands()
        @processPosts()
        @startPlanner()

  processLands: () =>
    # prepare data
    for land in @data["lands"]
      if land["type"] == "mountain"
        s = land["slug"]

        if @lands_posts[ s ] == undefined
          @lands.push(land)
          @lands_posts[ s ] = []

        for post in @data["posts"]
          if s in post["lands"]
            @lands_posts[ s ].push(post)

  processPosts: () =>
    currentDate = new Date()
    monthMs = 30*24*3600*1000

    for land in @lands
      s = land["slug"]
      posts = @lands_posts[s]

      visit_count = 0
      visit_within_1_months = 0
      visit_within_2_months = 0
      visit_within_3_months = 0
      visit_months_since = Infinity

      for post in posts
        visit_count += 1

        date = new Date( post["date"] )

        # within months
        month_diff = date.getMonth() - currentDate.getMonth()

        if month_diff < 0
          month_diff += 12

        if month_diff <= 1
          visit_within_1_months += 1
        if month_diff <= 2
          visit_within_2_months += 1
        if month_diff <= 3
          visit_within_3_months += 1

        # months since
        months_since = Math.round( ( currentDate.getTime() - date.getTime() ) / monthMs )
        if ( months_since < visit_months_since )
          visit_months_since = months_since

        #console.log  date, currentDate, month_diff


      # join data
      h = {}
      h["slug"] = s
      h["name"] = land["name"]
      h["visit_count"] = visit_count
      h["visit_within_1_months"] = visit_within_1_months
      h["visit_within_2_months"] = visit_within_2_months
      h["visit_within_3_months"] = visit_within_3_months
      if visit_months_since != Infinity
        h["visit_months_since"] = visit_months_since
      else
        h["visit_months_since"] = "---"  



      @land_outputs.push(h)

    console.log(@land_outputs)

  startPlanner: () ->
    $("#content").html("")

    main_object = $("<table>",
        id: "planner-table"
        class: "planner-table"
      ).appendTo "#content"

    s = "<tr>"

    s += "<th>Nazwa</th>"
    s += "<th>Wizyt (dni)</th>"
    s += "<th>1msc</th>"
    s += "<th>2msc</th>"
    s += "<th>3msc</th>"
    s += "<th>Miesięcy temu</th>"

    s += "</tr>"

    $(s).appendTo(main_object)

    for lo in @land_outputs
      s = "<tr>"

      s += "<td>" + lo["name"] + "</td>"
      s += "<td>" + lo["visit_count"] + "</td>"
      s += "<td>" + lo["visit_within_1_months"] + "</td>"
      s += "<td>" + lo["visit_within_2_months"] + "</td>"
      s += "<td>" + lo["visit_within_3_months"] + "</td>"
      s += "<td>" + lo["visit_months_since"] + "</td>"

      s += "</tr>"

      $(s).appendTo(main_object)
