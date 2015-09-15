class @BlogSummary
  constructor: ->
  
  # run everything
  start: () ->
    $.ajax
      url: "/payload.json"
      success: (data) =>
        @data = data
        @startSummary()
   
  startSummary: () ->
    $("#content").html('<ul id="land-tree" class="summary"></ul>')
    
    for land_type in @data["land_types"]
      land_type_object = $("<li>",
        id: land_type.slug
        class: "summary-land-type"
      ).appendTo "#land-tree"

      $("<span>",
        text: land_type.name
        title: land_type.name
      ).appendTo(land_type_object)     

      land_type_container = $("<ul>",
        id: land_type.slug
        class: "summary-lands-container"
      ).appendTo(land_type_object)


      for land in @data["lands"]
        if land.type ==  land_type.slug
        
          land_object = $("<li>",
            id: land.slug
            class: "summary-land"
          ).appendTo(land_type_container)

          $("<a>",
            text: land.name
            title: land.name
            href: land.url
          ).appendTo(land_object)
      
          posts_container = $("<ul>",
            class: "summary-posts-container"
          ).appendTo(land_object)

          for post in @data["posts"]
            if post.lands.indexOf(land.slug) >= 0

              post_element = $("<li>",
                class: "summary-post"
              ).appendTo(posts_container)

              $("<a>",
                text: post.date + " - " + post.title
                title: post.date + " - " + post.title
                href: post.url
              ).appendTo(post_element)
              
    