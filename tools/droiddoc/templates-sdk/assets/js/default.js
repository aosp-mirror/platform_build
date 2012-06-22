var navBarIsFixed = false;
$(document).ready(function() {
  // init the fullscreen toggle click event
  $('#nav-swap .fullscreen').click(function(){
    if ($(this).hasClass('disabled')) {
      toggleFullscreen(true);
    } else {
      toggleFullscreen(false);
    }
  });
  
  // initialize the divs with custom scrollbars
  $('.scroll-pane').jScrollPane( {verticalGutter:0} );
  
  // add HRs below all H2s (except for a few other h2 variants)
  $('h2').not('#qv h2').not('#tb h2').not('#devdoc-nav h2').css({marginBottom:0}).after('<hr/>');
  
  // set search's onkeyup handler here so we can show suggestions even while search results are visible
  $("#search_autocomplete").keyup(function() {return search_changed(event, false, '/')});

  // set up the search close button
  $('.search .close').click(function() {
    $searchInput = $('#search_autocomplete');
    $searchInput.attr('value', '');
    $(this).addClass("hide");
    $("#search-container").removeClass('active');
    $("#search_autocomplete").blur();
    search_focus_changed($searchInput.get(), false);  // see search_autocomplete.js
    hideResults();  // see search_autocomplete.js
  });
  $('.search').click(function() {
    if (!$('#search_autocomplete').is(":focused")) {
        $('#search_autocomplete').focus();
    }
  });

  // Set up quicknav
  var quicknav_open = false;  
  $("#btn-quicknav").click(function() {
    if (quicknav_open) {
      $(this).removeClass('active');
      quicknav_open = false;
      collapse();
    } else {
      $(this).addClass('active');
      quicknav_open = true;
      expand();
    }
  })
  
  var expand = function() {
   $('#header-wrap').addClass('quicknav');
   $('#quicknav').stop().show().animate({opacity:'1'});
  }
  
  var collapse = function() {
    $('#quicknav').stop().animate({opacity:'0'}, 100, function() {
      $(this).hide();
      $('#header-wrap').removeClass('quicknav');
    });
  }
  
  
  //Set up search
  $("#search_autocomplete").focus(function() {
    $("#search-container").addClass('active');
  })
  $("#search-container").mouseover(function() {
    $("#search-container").addClass('active');
    $("#search_autocomplete").focus();
  })
  $("#search-container").mouseout(function() {
    if ($("#search_autocomplete").is(":focus")) return;
    if ($("#search_autocomplete").val() == '') {
      setTimeout(function(){
        $("#search-container").removeClass('active');
        $("#search_autocomplete").blur();
      },250);
    }
  })
  $("#search_autocomplete").blur(function() {
    if ($("#search_autocomplete").val() == '') {
      $("#search-container").removeClass('active');
    }
  })

    
  // prep nav expandos
  var pagePath = document.location.pathname;
  // account for intl docs by removing the intl/*/ path
  if (pagePath.indexOf("/intl/") == 0) {
    pagePath = pagePath.substr(pagePath.indexOf("/",6)); // start after intl/ to get last /
  }
  
  if (pagePath.indexOf(SITE_ROOT) == 0) {
    if (pagePath == '' || pagePath.charAt(pagePath.length - 1) == '/') {
      pagePath += 'index.html';
    }
  }

  if (SITE_ROOT.match(/\.\.\//) || SITE_ROOT == '') {
    // If running locally, SITE_ROOT will be a relative path, so account for that by
    // finding the relative URL to this page. This will allow us to find links on the page
    // leading back to this page.
    var pathParts = pagePath.split('/');
    var relativePagePathParts = [];
    var upDirs = (SITE_ROOT.match(/(\.\.\/)+/) || [''])[0].length / 3;
    for (var i = 0; i < upDirs; i++) {
      relativePagePathParts.push('..');
    }
    for (var i = 0; i < upDirs; i++) {
      relativePagePathParts.push(pathParts[pathParts.length - (upDirs - i) - 1]);
    }
    relativePagePathParts.push(pathParts[pathParts.length - 1]);
    pagePath = relativePagePathParts.join('/');
  } else {
    // Otherwise the page path is already an absolute URL
  }

  // select current page in sidenav and set up prev/next links if they exist
  var $selNavLink = $('#nav').find('a[href="' + pagePath + '"]');
  if ($selNavLink.length) {
    $selListItem = $selNavLink.closest('li');

    $selListItem.addClass('selected');
    $selListItem.closest('li.nav-section').addClass('expanded');
    $selListItem.closest('li.nav-section').children('ul').show();
    $selListItem.closest('li.nav-section').parent().closest('li.nav-section').addClass('expanded');
    $selListItem.closest('li.nav-section').parent().closest('ul').show();
    
    
  //  $selListItem.closest('li.nav-section').closest('li.nav-section').addClass('expanded');
  //  $selListItem.closest('li.nav-section').closest('li.nav-section').children('ul').show();  

    // set up prev links
    var $prevLink = [];
    var $prevListItem = $selListItem.prev('li');
    
    var crossBoundaries = ($("body.design").length > 0) || ($("body.guide").length > 0) ? true : false; // navigate across topic boundaries only in design docs
    if ($prevListItem.length) {
      if ($prevListItem.hasClass('nav-section')) {
        if (crossBoundaries) {
          // jump to last topic of previous section
          $prevLink = $prevListItem.find('a:last');
        }
      } else {
        // jump to previous topic in this section
        $prevLink = $prevListItem.find('a:eq(0)');
      }
    } else {
      // jump to this section's index page (if it exists)
      var $parentListItem = $selListItem.parents('li');
      $prevLink = $selListItem.parents('li').find('a');
      
      // except if cross boundaries aren't allowed, and we're at the top of a section already (and there's another parent)
      if (!crossBoundaries && $parentListItem.hasClass('nav-section') && $selListItem.hasClass('nav-section')) {
        $prevLink = [];
      }
    }

    if ($prevLink.length) {
      var prevHref = $prevLink.attr('href');
      if (prevHref == SITE_ROOT + 'index.html') {
        // Don't show Previous when it leads to the homepage
      } else {
        $('.prev-page-link').attr('href', $prevLink.attr('href')).removeClass("hide");
      }
    } 

    // set up next links
    var $nextLink = [];
    var startCourse = false;
    var startClass = false;
    var training = $(".next-class-link").length; // decides whether to provide "next class" link
    var isCrossingBoundary = false;
    
    if ($selListItem.hasClass('nav-section')) {
      // we're on an index page, jump to the first topic
      $nextLink = $selListItem.find('ul').find('a:eq(0)');

      // if there aren't any children, go to the next section (required for About pages)
      if($nextLink.length == 0) {
        $nextLink = $selListItem.next('li').find('a');
      }
      
      // Handle some Training specialties
      if ($selListItem.parent().is("#nav") && $(".start-course-link").length) {
        // this means we're at the very top of the TOC hierarchy
        startCourse = true;
      } else if ($(".start-class-link").length) {
        // this means this page has children but is not at the top (it's a class, not a course)
        startClass = true;
      }
    } else {
      // jump to the next topic in this section (if it exists)
      $nextLink = $selListItem.next('li').find('a:eq(0)');
      if (!$nextLink.length) {
        if (crossBoundaries || training) {
          // no more topics in this section, jump to the first topic in the next section
          $nextLink = $selListItem.parents('li:eq(0)').next('li.nav-section').find('a:eq(0)');
          isCrossingBoundary = true;
        }
      }
    }
    if ($nextLink.length) {
      if (startCourse || startClass) {
        if (startCourse) {
          $('.start-course-link').attr('href', $nextLink.attr('href')).removeClass("hide");
        } else {
          $('.start-class-link').attr('href', $nextLink.attr('href')).removeClass("hide");
        }
        // if there's no training bar (below the start button), then we need to add a bottom border to button
        if (!$("#tb").length) {
          $('.start-course-link').css({'border-bottom':'1px solid #DADADA'});
          $('.start-class-link').css({'border-bottom':'1px solid #DADADA'});
        }
      } else if (training && isCrossingBoundary) {
        $('.content-footer.next-class').show();
        $('.next-page-link').attr('href','').removeClass("hide").addClass("disabled").click(function() {
              return false;
            });
        $('.next-class-link').attr('href',$nextLink.attr('href')).removeClass("hide").append($nextLink.html());
        $('.next-class-link').find('.new').empty();
      } else {
        $('.next-page-link').attr('href', $nextLink.attr('href')).removeClass("hide");
      }
    }
    
  }



  // Set up expand/collapse behavior
  $('#nav li.nav-section .nav-section-header').click(function() {
    var section = $(this).closest('li.nav-section');
    if (section.hasClass('expanded')) {
    /* hide me */
    //  if (section.hasClass('selected') || section.find('li').hasClass('selected')) {
   //   /* but not if myself or my descendents are selected */
   //     return;
    //  }
      section.children('ul').slideUp(250, function() {
        section.closest('li').removeClass('expanded');
        resizeNav();
      });
    } else {
    /* show me */
      // first hide all other siblings
      var $others = $('li.nav-section.expanded', $(this).closest('ul'));
      $others.removeClass('expanded').children('ul').slideUp(250);
      
      // now expand me
      section.closest('li').addClass('expanded');
      section.children('ul').slideDown(250, function() {
        resizeNav();
      });
    }
  });
  
  $(".scroll-pane").scroll(function(event) {
      event.preventDefault();
      return false;
  });

  /* Resize nav height when window height changes */
  $(window).resize(function() {
    var stylesheet = $('link[rel="stylesheet"][title="fullscreen"]');
    setNavBarLeftPos(); // do this even if sidenav isn't fixed because it could become fixed
    // make sidenav behave when resizing the window and side-scolling is a concern
    if (navBarIsFixed) {
      if ((stylesheet.attr("disabled") == "disabled") || stylesheet.length == 0) {
        updateSideNavPosition();
      } else {
        updateSidenavFullscreenWidth();
      }
    }
    resizeNav();
  });


  // Set up fixed navbar
  var prevScrollLeft = 0; // used to compare current position to previous position of horiz scroll
  $(window).scroll(function(event) {
    if (event.target.nodeName == "DIV") {
      // Dump scroll event if the target is a DIV, because that means the event is coming
      // from a scrollable div and so there's no need to make adjustments to our layout
      return;
    }
    var scrollTop = $(window).scrollTop();    
    var headerHeight = $('#header').outerHeight();
    var subheaderHeight = $('#nav-x').outerHeight();
    var searchResultHeight = $('#searchResults').is(":visible") ? $('#searchResults').outerHeight() : 0;
    var totalHeaderHeight = headerHeight + subheaderHeight + searchResultHeight;
    var navBarShouldBeFixed = scrollTop > totalHeaderHeight;
   
    var scrollLeft = $(window).scrollLeft();
    // When the sidenav is fixed and user scrolls horizontally, reposition the sidenav to match
    if (navBarIsFixed && (scrollLeft != prevScrollLeft)) {
      updateSideNavPosition();
      prevScrollLeft = scrollLeft;
    }
    
    // Don't continue if the header is sufficently far away (to avoid intensive resizing that slows scrolling)
    if (navBarIsFixed && navBarShouldBeFixed) {
      return;
    }
    
    if (navBarIsFixed != navBarShouldBeFixed) {
      if (navBarShouldBeFixed) {
        // make it fixed
        var width = $('#devdoc-nav').width();
        var margin = $('#devdoc-nav').parent().css('margin');
        $('#devdoc-nav')
            .addClass('fixed')
            .css({'width':width+'px','margin':margin})
            .prependTo('#body-content');
        // add neato "back to top" button
        $('#devdoc-nav a.totop').css({'display':'block','width':$("#nav").innerWidth()+'px'});
        
        // update the sidenaav position for side scrolling
        updateSideNavPosition();
      } else {
        // make it static again
        $('#devdoc-nav')
            .removeClass('fixed')
            .css({'width':'auto','margin':''})
            .prependTo('#side-nav');
        $('#devdoc-nav a.totop').hide();
      }
      navBarIsFixed = navBarShouldBeFixed;
    } 
    
    resizeNav(250); // pass true in order to delay the scrollbar re-initialization for performance reasons
  });

  
  var navBarLeftPos;
  if ($('#devdoc-nav').length) {
    setNavBarLeftPos();
  }


  // Stop expand/collapse behavior when clicking on nav section links (since we're navigating away
  // from the page)
  $('.nav-section-header').find('a:eq(0)').click(function(evt) {
    window.location.href = $(this).attr('href');
    return false;
  });

  // Set up play-on-hover <video> tags.
  $('video.play-on-hover').bind('click', function(){
    $(this).get(0).load(); // in case the video isn't seekable
    $(this).get(0).play();
  });

  // Set up tooltips
  var TOOLTIP_MARGIN = 10;
  $('acronym').each(function() {
    var $target = $(this);
    var $tooltip = $('<div>')
        .addClass('tooltip-box')
        .text($target.attr('title'))
        .hide()
        .appendTo('body');
    $target.removeAttr('title');

    $target.hover(function() {
      // in
      var targetRect = $target.offset();
      targetRect.width = $target.width();
      targetRect.height = $target.height();

      $tooltip.css({
        left: targetRect.left,
        top: targetRect.top + targetRect.height + TOOLTIP_MARGIN
      });
      $tooltip.addClass('below');
      $tooltip.show();
    }, function() {
      // out
      $tooltip.hide();
    });
  });

  // Set up <h2> deeplinks
  $('h2').click(function() {
    var id = $(this).attr('id');
    if (id) {
      document.location.hash = id;
    }
  });

  //Loads the +1 button
  var po = document.createElement('script'); po.type = 'text/javascript'; po.async = true;
  po.src = 'https://apis.google.com/js/plusone.js';
  var s = document.getElementsByTagName('script')[0]; s.parentNode.insertBefore(po, s);


  // Revise the sidenav widths to make room for the scrollbar 
  // which avoids the visible width from changing each time the bar appears
  var $sidenav = $("#side-nav");
  var sidenav_width = parseInt($sidenav.innerWidth());
    
  $("#devdoc-nav  #nav").css("width", sidenav_width - 4 + "px"); // 4px is scrollbar width


  $(".scroll-pane").removeAttr("tabindex"); // get rid of tabindex added by jscroller
  
  if ($(".scroll-pane").length > 1) {
    // Check if there's a user preference for the panel heights
    var cookieHeight = readCookie("reference_height");
    if (cookieHeight) {
      restoreHeight(cookieHeight);
    }
  }
  
  resizeNav();


});



  function toggleFullscreen(enable) {
    var delay = 20;
    var enabled = false;
    var stylesheet = $('link[rel="stylesheet"][title="fullscreen"]');
    if (enable) {
      // Currently NOT USING fullscreen; enable fullscreen
      stylesheet.removeAttr('disabled');
      $('#nav-swap .fullscreen').removeClass('disabled');
      $('#devdoc-nav').css({left:''});
      setTimeout(updateSidenavFullscreenWidth,delay); // need to wait a moment for css to switch
      enabled = true;
    } else {
      // Currently USING fullscreen; disable fullscreen
      stylesheet.attr('disabled', 'disabled');
      $('#nav-swap .fullscreen').addClass('disabled');
      setTimeout(updateSidenavFixedWidth,delay); // need to wait a moment for css to switch
      enabled = false;
    }
    writeCookie("fullscreen", enabled, null, null);
    setNavBarLeftPos();
    resizeNav(delay);
    setTimeout(initSidenavHeightResize,delay);
  }

  
  function setNavBarLeftPos() {
    navBarLeftPos = $('#body-content').offset().left;
  }


  function updateSideNavPosition() {
    var newLeft = $(window).scrollLeft() - navBarLeftPos;
    $('#devdoc-nav').css({left: -newLeft});
    $('#devdoc-nav .totop').css({left: -(newLeft - parseInt($('#side-nav').css('margin-left')))});
  }
  