class @TodoRoute
  constructor: ->
    @route_destination_names = []
    @route_destination_major_names = []

    @route_destination_objects = []
    @route_destination_major_objects = []

  # run everything
  start: () ->
    # load payload for searching similar routes-posts
    $.ajax
      url: "/payload.json"
      success: (data) =>
        @data = data
        @loadRoutes()
        # first execute
        @executeFilter()

  executeFilter: () =>
    filter_route_from = $("#filter-route-from").val()
    filter_route_to = $("#filter-route-to").val()
    filter_route_both = $("#filter-route-both").val()
    filter_route_both_major = $("#filter-route-both-major").val()

    filter_route_total_cost = $("#filter-total-cost-less-than").val()
    filter_route_transport_cost = $("#filter-transport-cost-less-than").val()

    # range input
    filter_min_distance = parseInt($("#min-distance").val())
    filter_max_distance = parseInt($("#max-distance").val())
    filter_direction = parseInt($("#direction").val()) % 180

    # distance range inputs operations
    $("#distance-range").text(filter_min_distance + "-" + filter_max_distance + "km")

    if filter_direction < 0
      $("#direction-name").text("dowolnym")
    else
      rotate = 90 + filter_direction
      icon_string = '<i style="transform: rotate(' + rotate + '); -ms-transform: rotate(' + rotate + 'deg); -webkit-transform: rotate(' + rotate + 'deg);" class="fa">&#xf07e;</i>'
      $("#direction-name").html(icon_string)

    # show all
    $(".todo_route").show()

    # hide shorter
    if filter_min_distance > 0
      $(".todo_route").each (index, todo_route) =>
        if parseInt($(todo_route).data("route-distance")) < parseInt(filter_min_distance)
          $(todo_route).hide()

    # hide longer
    if filter_max_distance > 0
      $(".todo_route").each (index, todo_route) =>
        if parseInt($(todo_route).data("route-distance")) > parseInt(filter_max_distance)
          $(todo_route).hide()

    # hide other direction
    # >= because 0 is also valid
    if filter_direction >= 0
      direction_width = 15
      $(".todo_route").each (index, todo_route) =>
        route_direction = parseInt($(todo_route).data("route-real-direction")) % 180
        direction_diff = Math.abs(filter_direction - route_direction)
        if direction_diff <= direction_width
          console.log("show " + direction_diff)
        else
          console.log("hide " + direction_diff)
          $(todo_route).hide()

      # # this could be changed
      # direction_width = 15
      # direction_from = filter_direction - direction_width
      # direction_to = filter_direction + direction_width
      #
      # direction_second_from = direction_from
      # direction_second_to = direction_to
      #
      # console.log("direction_from = " + direction_from)
      # console.log("direction_to = " + direction_to)
      # console.log("direction_second_from = " + direction_second_from)
      # console.log("direction_second_to = " + direction_second_to)
      #
      # # 1: direction_from is below 0 -> add another range near 180
      # if direction_from < 0
      #   direction_second_from = 0
      #   direction_second_to = direction_to
      #
      #   direction_from = 180 + direction_from
      #   direction_to = 180
      #
      # # 2: both are within 0 and 180 -> direct
      # # nothing, second range was already defined/copied
      #
      # # 3: direction_to is above 180 -> add another range near 0
      # if direction_to > 180
      #   direction_second_from = direction_from
      #   direction_second_to = 180
      #
      #   direction_from = 0
      #   direction_to = direction_to - 180
      #
      # $(".todo_route").each (index, todo_route) =>
      #   rd = parseInt($(todo_route).data("route-distance")) % 180
      #   console.log("normalized route direction " + rd)
      #   console.log("logic1 " + ((rd >= direction_from) && (rd <= direction_to)))
      #   console.log("logic2 " + ((rd >= direction_second_from) && (rd <= direction_second_to)))
      #   if ((rd >= direction_from) && (rd <= direction_to) || (rd >= direction_second_from) && (rd <= direction_second_to))
      #     console.log("show " + rd + " / " + filter_direction)
      #   else
      #     console.log("hide " + rd + " / " + filter_direction)
      #     $(todo_route).hide()

    # additive hiding (and logic)
    if filter_route_from.length > 1
      $(".todo_route").each (index, todo_route) =>
        if $(todo_route).data("route-from") != filter_route_from
          $(todo_route).hide()

    if filter_route_to.length > 1
      $(".todo_route").each (index, todo_route) =>
        if $(todo_route).data("route-to") != filter_route_to
          $(todo_route).hide()

    if filter_route_both.length > 1
      $(".todo_route").each (index, todo_route) =>
        if ($(todo_route).data("route-to") != filter_route_both) && ($(todo_route).data("route-from") != filter_route_both)
          $(todo_route).hide()

    if filter_route_both_major.length > 1
      $(".todo_route").each (index, todo_route) =>
        if ($(todo_route).data("route-to-major") != filter_route_both_major) && ($(todo_route).data("route-from-major") != filter_route_both_major)
          $(todo_route).hide()


    if filter_route_total_cost.length > 1
      $(".todo_route").each (index, todo_route) =>
        if parseFloat($(todo_route).data("route-total-cost") * 60.0) > parseFloat(filter_route_total_cost)
          $(todo_route).hide()

    if filter_route_transport_cost.length > 1
      $(".todo_route").each (index, todo_route) =>
        c = 0

        if $(todo_route).data("route-from-cost-minutes")
          c += parseFloat($(todo_route).data("route-from-cost-minutes"))

        if $(todo_route).data("route-to-cost-minutes")
          c += parseFloat($(todo_route).data("route-to-cost-minutes"))

        if c > parseFloat(filter_route_transport_cost)
          $(todo_route).hide()

  loadRoutes: () =>
    # load all from/to
    $(".todo_route").each (index, todo_route) =>

      # all
      route_from = $(todo_route).data("route-from")
      route_from_cost_minutes = $(todo_route).data("route-from-cost-minutes")
      route_from_distance = $(todo_route).data("route-from-distance")
      route_from_direction_human = $(todo_route).data("route-from-direction-human")
      route_from_label = route_from
      if parseFloat(route_from_distance) > 0.0
        route_from_label += " (" + Math.round(parseFloat(route_from_distance)) + "km " + route_from_direction_human + ")"

      route_to = $(todo_route).data("route-to")
      route_to_cost_minutes = $(todo_route).data("route-to-cost-minutes")
      route_to_distance = $(todo_route).data("route-to-distance")
      route_to_direction_human = $(todo_route).data("route-to-direction-human")
      route_to_label = route_to
      if parseFloat(route_to_distance) > 0.0
        route_to_label += " (" + Math.round(parseFloat(route_to_distance)) + "km " + route_to_direction_human + ")"

      # only major
      route_from_major = $(todo_route).data("route-from-major")
      route_from_major_cost_minutes = null #$(todo_route).data("route-from-cost-minutes")
      route_from_major_distance = null #$(todo_route).data("route-from-distance")
      route_from_major_direction_human = null #$(todo_route).data("route-from-direction-human")
      route_from_major_label = route_from_major
      if parseFloat(route_from_major_distance) > 0.0
        route_from_major_label += " (" + Math.round(parseFloat(route_from_major_distance)) + "km " + route_from_major_direction_human + ")"

      route_to_major = $(todo_route).data("route-to-major")
      route_to_major_cost_minutes = null #$(todo_route).data("route-to-cost-minutes")
      route_to_major_distance = null #$(todo_route).data("route-to-distance")
      route_to_major_direction_human = null #$(todo_route).data("route-to-direction-human")
      route_to_major_label = route_to_major
      if parseFloat(route_to_major_distance) > 0.0
        route_to_label += " (" + Math.round(parseFloat(route_to_major_distance)) + "km " + route_to_major_direction_human + ")"

      # regular, all
      if @route_destination_names.indexOf(route_from) < 0
        @route_destination_names.push(route_from)
        @route_destination_objects.push(
          name: route_from,
          cost_minutes: route_from_cost_minutes,
          distance: route_from_distance,
          direction_human: route_from_direction_human,
          label: route_from_label
        )

      if @route_destination_names.indexOf(route_to) < 0
        @route_destination_names.push(route_to)
        @route_destination_objects.push(
          name: route_to,
          cost_minutes: route_to_cost_minutes,
          distance: route_to_distance,
          direction_human: route_to_direction_human,
          label: route_to_label
        )

      # major
      if route_from_major.length > 1
        if @route_destination_major_names.indexOf(route_from_major) < 0
          @route_destination_major_names.push(route_from_major)
          @route_destination_major_objects.push(
            name: route_from_major,
            cost_minutes: route_from_major_cost_minutes,
            distance: route_from_major_distance,
            direction_human: route_from_major_direction_human,
            label: route_from_major_label
          )

      if route_to_major.length > 1
        if @route_destination_major_names.indexOf(route_to_major) < 0
          @route_destination_major_names.push(route_to_major)
          @route_destination_major_objects.push(
            name: route_to_major,
            cost_minutes: route_to_major_cost_minutes,
            distance: route_to_major_distance,
            direction_human: route_to_major_direction_human,
            label: route_to_major_label
          )

    @route_destination_names = @route_destination_names.sort()
    @route_destination_objects = @route_destination_objects.sort (a, b) ->
      a.name.localeCompare(b.name)

    @route_destination_major_names = @route_destination_major_names.sort()
    @route_destination_major_objects = @route_destination_major_objects.sort (a, b) ->
      a.name.localeCompare(b.name)

    for route_element_object in @route_destination_objects

      $("#filter-route-from").append $("<option>",
        value: route_element_object.name
        text: route_element_object.label
      )

      $("#filter-route-to").append $("<option>",
        value: route_element_object.name
        text: route_element_object.label
      )

      $("#filter-route-both").append $("<option>",
        value: route_element_object.name
        text: route_element_object.label
      )

    # add filter data - major
    for route_element_major_object in @route_destination_major_objects

      $("#filter-route-both-major").append $("<option>",
        value: route_element_major_object.name
        text: route_element_major_object.label
      )

    # add filter callbacks
    $(".route-filter-field").on "change", =>
      @executeFilter()
