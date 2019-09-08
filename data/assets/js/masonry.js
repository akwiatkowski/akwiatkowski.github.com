function masInit() {
  windowWidth = $(window).width()
  colWidth = 600;

  if (windowWidth < 650) {
    windowWidth = 350;
    colWidth = 300;
  }

  // masonry
  var $grid = $('.grid').masonry({
    fitWidth: true,
    columnWidth: colWidth,
    gutter: 20
  });
}

function masInitScroll() {
  $(window).scroll(function() {
    masShowNext();
  });

  $('.grid').infinitescroll({
    behavior: 'local',
    binder: $('.grid'), // scroll on this element rather than on the window
    // other options
  });

  masShowLoop();
}

function masShowNext() {
  isVis = $('#after-grid').visible(true);
  if (isVis) {
    visible_count = $(".grid-item:not('.hidden')").length;
    windowWidth = $(window).width()
    colWidth = 600;

    if (windowWidth < 650) {
      windowWidth = 350;
      colWidth = 300;
    }


    cols = Math.floor( windowWidth / colWidth );
    restCols = visible_count % cols;
    restCols = cols - restCols;

    // looks better on mobile
    if (cols == 1) {
      restCols += 3;
    }

    console.log( "cols " + cols + " rest " + restCols );

    showNextPosts = cols + restCols;

    $(".grid-item.hidden:lt(" + showNextPosts + ")").hide().removeClass("hidden").show();
    $('.grid').masonry();
    return true;
  }
  return false;
}

function masShowLoop() {
  setTimeout(function(){
    result = masShowNext();
    if (result) {
      masShowLoop();
    }
  },
  600);
}

function galleryMasonry() {
  // lg stuff
  var $gallery = $(".lg-enabled").lightGallery();
  $gallery.on('onAfterAppendSubHtml.lg', function(event, prevIndex, index){
    obj = $(".gallery-image").eq(prevIndex)
    url = obj.data("postUrl")
    urlHtml = "<a href=\"" + url + "\">wpis</a>"

    $(".lg-sub-html").append(" - " + urlHtml)
  });
  $(".gallery-zoom").hide();
  $(".gallery-book").hide();

  var $grid = $('.post-photo-gallery').imagesLoaded( function() {
    // $grid.masonry({
    //   itemSelector: ".gallery-image",
    //   fitWidth: true,
    //   columnWidth: ".gallery-image"
    // });
  });
}
