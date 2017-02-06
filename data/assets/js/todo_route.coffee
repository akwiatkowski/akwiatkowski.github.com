class @TodoRoute
  constructor: ->
    @route_destination_names = []
    @route_destination_objects = []

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
    filter_route_less = $("#filter-distance-less-than").val()
    filter_route_more = $("#filter-distance-more-than").val()

    filter_route_flag_small = $("#filter-flag-small").prop( "checked")
    filter_route_flag_normal = $("#filter-flag-normal").prop( "checked")
    filter_route_flag_long = $("#filter-flag-long").prop( "checked")
    filter_route_flag_touring = $("#filter-flag-touring").prop( "checked")

    filter_route_total_cost = $("#filter-total-cost-less-than").val()
    filter_route_transport_cost = $("#filter-transport-cost-less-than").val()

    # hide not matching with filters
    # boolean checkboxes - `or`
    $(".todo_route").hide()

    $(".todo_route").each (index, todo_route) =>
      if $(todo_route).data("route-flag-small") && filter_route_flag_small
        $(todo_route).show()

      if $(todo_route).data("route-flag-normal") && filter_route_flag_normal
        $(todo_route).show()

      if $(todo_route).data("route-flag-long") && filter_route_flag_long
        $(todo_route).show()

      if $(todo_route).data("route-flag-touring") && filter_route_flag_touring
        $(todo_route).show()

    # select filters - `and`
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

    if filter_route_less.length > 1
      $(".todo_route").each (index, todo_route) =>
        if parseInt($(todo_route).data("route-distance")) > parseInt(filter_route_less)
          $(todo_route).hide()

    if filter_route_more.length > 1
      $(".todo_route").each (index, todo_route) =>
        if parseInt($(todo_route).data("route-distance")) < parseInt(filter_route_more)
          $(todo_route).hide()

    if filter_route_total_cost.length > 1
      $(".todo_route").each (index, todo_route) =>
        if parseFloat($(todo_route).data("route-total-cost") * 60.0) > parseFloat(filter_route_total_cost)
          $(todo_route).hide()

    if filter_route_transport_cost.length > 1
      $(".todo_route").each (index, todo_route) =>
        c = 0
        if $(todo_route).data("route-from-cost").length > 1
          c += parseFloat($(todo_route).data("route-from-cost"))
        if $(todo_route).data("route-to-cost").length > 1
          c += parseFloat($(todo_route).data("route-to-cost"))

        console.log(c)
        if c > parseFloat(filter_route_transport_cost)
          $(todo_route).hide()

  loadRoutes: () =>
    # load all from/to
    $(".todo_route").each (index, todo_route) =>

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

    @route_destination_names = @route_destination_names.sort()
    @route_destination_objects = @route_destination_objects.sort (a, b) ->
      a.name.localeCompare(b.name)

    # add filter data
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

    # add filter callbacks
    $(".route-filter-field").on "change", =>
      @executeFilter()
