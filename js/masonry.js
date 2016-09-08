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
    rest_cols = visible_count % cols;
    rest_cols = cols - rest_cols;

    console.log( "cols " + cols + " rest " + rest_cols );

    show_cols = cols + rest_cols;

    $(".grid-item.hidden:lt(" + show_cols + ")").hide().removeClass("hidden").show();
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
