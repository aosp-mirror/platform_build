var cookie_namespace = 'android_developer';
var isMobile = false; // true if mobile, so we can adjust some layout
var mPagePath; // initialized in ready() function

var basePath = getBaseUri(location.pathname);
var SITE_ROOT = toRoot + basePath.substring(1, basePath.indexOf("/", 1));

// TODO(akassay) generate this var in the reference doc build.
var API_LEVELS = ['1', '2', '3', '4', '5', '6', '7', '8', '9',
      '10', '11', '12', '13', '14', '15', '16',
      '17', '18', '19', '20', '21', '22', '23', '24'];
var METADATA = METADATA || {};
var RESERVED_METADATA_CATEGORY_NAMES = ['extras', 'carousel', 'collections',
                                        'searchHeroCollections'];

// Ensure that all ajax getScript() requests allow caching
$.ajaxSetup({
  cache: true
});

/******  ON LOAD SET UP STUFF *********/

$(document).ready(function() {

  // prep nav expandos
  var pagePath = location.href.replace(location.hash, '');
  // account for intl docs by removing the intl/*/ path
  if (pagePath.indexOf("/intl/") == 0) {
    pagePath = pagePath.substr(pagePath.indexOf("/", 6)); // start after intl/ to get last /
  }

  if (pagePath.indexOf(SITE_ROOT) == 0) {
    if (pagePath == '' || pagePath.charAt(pagePath.length - 1) == '/') {
      pagePath += 'index.html';
    }
  }

  // Need a copy of the pagePath before it gets changed in the next block;
  // it's needed to perform proper tab highlighting in offline docs (see rootDir below)
  var pagePathOriginal = pagePath;
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

  // set global variable so we can highlight the sidenav a bit later (such as for google reference)
  // and highlight the sidenav
  mPagePath = pagePath;

  // Check for params and remove them.
  mPagePath = mPagePath.split('?')[0];
  highlightSidenav();

  // set up prev/next links if they exist
  var $selNavLink = $('#nav').find('a[href="' + pagePath + '"]');
  var $selListItem;
  if ($selNavLink.length) {
    $selListItem = $selNavLink.closest('li');

    // set up prev links
    var $prevLink = [];
    var $prevListItem = $selListItem.prev('li');

    var crossBoundaries = ($("body.design").length > 0) || ($("body.guide").length > 0) ? true :
false; // navigate across topic boundaries only in design docs
    if ($prevListItem.length) {
      if ($prevListItem.hasClass('nav-section') || crossBoundaries) {
        // jump to last topic of previous section
        $prevLink = $prevListItem.find('a:last');
      } else if (!$selListItem.hasClass('nav-section')) {
        // jump to previous topic in this section
        $prevLink = $prevListItem.find('a:eq(0)');
      }
    } else {
      // jump to this section's index page (if it exists)
      var $parentListItem = $selListItem.parents('li');
      $prevLink = $selListItem.parents('li').find('a');

      // except if cross boundaries aren't allowed, and we're at the top of a section already
      // (and there's another parent)
      if (!crossBoundaries && $parentListItem.hasClass('nav-section') &&
                           $selListItem.hasClass('nav-section')) {
        $prevLink = [];
      }
    }

    // set up next links
    var $nextLink = [];
    var startClass = false;
    var isCrossingBoundary = false;

    if ($selListItem.hasClass('nav-section') && $selListItem.children('div.empty').length == 0) {
      // we're on an index page, jump to the first topic
      $nextLink = $selListItem.find('ul:eq(0)').find('a:eq(0)');

      // if there aren't any children, go to the next section (required for About pages)
      if ($nextLink.length == 0) {
        $nextLink = $selListItem.next('li').find('a');
      } else if ($('.topic-start-link').length) {
        // as long as there's a child link and there is a "topic start link" (we're on a landing)
        // then set the landing page "start link" text to be the first doc title
        $('.topic-start-link').text($nextLink.text().toUpperCase());
      }

      // If the selected page has a description, then it's a class or article homepage
      if ($selListItem.find('a[description]').length) {
        // this means we're on a class landing page
        startClass = true;
      }
    } else {
      // jump to the next topic in this section (if it exists)
      $nextLink = $selListItem.next('li').find('a:eq(0)');
      if ($nextLink.length == 0) {
        isCrossingBoundary = true;
        // no more topics in this section, jump to the first topic in the next section
        $nextLink = $selListItem.parents('li:eq(0)').next('li').find('a:eq(0)');
        if (!$nextLink.length) {  // Go up another layer to look for next page (lesson > class > course)
          $nextLink = $selListItem.parents('li:eq(1)').next('li.nav-section').find('a:eq(0)');
          if ($nextLink.length == 0) {
            // if that doesn't work, we're at the end of the list, so disable NEXT link
            $('.next-page-link').attr('href', '').addClass("disabled")
                                .click(function() { return false; });
            // and completely hide the one in the footer
            $('.content-footer .next-page-link').hide();
          }
        }
      }
    }

    if (startClass) {
      $('.start-class-link').attr('href', $nextLink.attr('href')).removeClass("hide");

      // if there's no training bar (below the start button),
      // then we need to add a bottom border to button
      if (!$("#tb").length) {
        $('.start-class-link').css({'border-bottom':'1px solid #DADADA'});
      }
    } else if (isCrossingBoundary && !$('body.design').length) {  // Design always crosses boundaries
      $('.content-footer.next-class').show();
      $('.next-page-link').attr('href', '')
                          .removeClass("hide").addClass("disabled")
                          .click(function() { return false; });
      // and completely hide the one in the footer
      $('.content-footer .next-page-link').hide();
      $('.content-footer .prev-page-link').hide();

      if ($nextLink.length) {
        $('.next-class-link').attr('href', $nextLink.attr('href'))
                             .removeClass("hide");

        $('.content-footer .next-class-link').append($nextLink.html());

        $('.next-class-link').find('.new').empty();
      }
    } else {
      $('.next-page-link').attr('href', $nextLink.attr('href'))
                          .removeClass("hide");
      // for the footer link, also add the previous and next page titles
      if ($prevLink.length) {
        $('.content-footer .prev-page-link').append($prevLink.html());
      }
      if ($nextLink.length) {
        $('.content-footer .next-page-link').append($nextLink.html());
      }
    }

    if (!startClass && $prevLink.length) {
      var prevHref = $prevLink.attr('href');
      if (prevHref == SITE_ROOT + 'index.html') {
        // Don't show Previous when it leads to the homepage
      } else {
        $('.prev-page-link').attr('href', $prevLink.attr('href')).removeClass("hide");
      }
    }
  }

  // Set up the course landing pages for Training with class names and descriptions
  if ($('body.trainingcourse').length) {
    var $classLinks = $selListItem.find('ul li a').not('#nav .nav-section .nav-section ul a');

    // create an array for all the class descriptions
    var $classDescriptions = new Array($classLinks.length);
    var lang = getLangPref();
    $classLinks.each(function(index) {
      var langDescr = $(this).attr(lang + "-description");
      if (typeof langDescr !== 'undefined' && langDescr !== false) {
        // if there's a class description in the selected language, use that
        $classDescriptions[index] = langDescr;
      } else {
        // otherwise, use the default english description
        $classDescriptions[index] = $(this).attr("description");
      }
    });

    var $olClasses  = $('<ol class="class-list"></ol>');
    var $liClass;
    var $h2Title;
    var $pSummary;
    var $olLessons;
    var $liLesson;
    $classLinks.each(function(index) {
      $liClass  = $('<li class="clearfix"></li>');
      $h2Title  = $('<a class="title" href="' + $(this).attr('href') + '"><h2 class="norule">' + $(this).html() + '</h2><span></span></a>');
      $pSummary = $('<p class="description">' + $classDescriptions[index] + '</p>');

      $olLessons  = $('<ol class="lesson-list"></ol>');

      $lessons = $(this).closest('li').find('ul li a');

      if ($lessons.length) {
        $lessons.each(function(index) {
          $olLessons.append('<li><a href="' + $(this).attr('href') + '">' + $(this).html() + '</a></li>');
        });
      } else {
        $pSummary.addClass('article');
      }

      $liClass.append($h2Title).append($pSummary).append($olLessons);
      $olClasses.append($liClass);
    });
    $('#classes').append($olClasses);
  }

  // Set up expand/collapse behavior
  initExpandableNavItems("#nav");

  // Set up play-on-hover <video> tags.
  $('video.play-on-hover').bind('click', function() {
    $(this).get(0).load(); // in case the video isn't seekable
    $(this).get(0).play();
  });

  // Set up play-on-click for <video> tags with a "video-wrapper".
  $('.video-wrapper > video').bind('click', function() {
    this.play();
    $(this.parentElement).addClass('playing');
  });

  // Set up tooltips
  var TOOLTIP_MARGIN = 10;
  $('acronym,.tooltip-link').each(function() {
    var $target = $(this);
    var $tooltip = $('<div>')
        .addClass('tooltip-box')
        .append($target.attr('title'))
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
      if (history && history.replaceState) {
        // Change url without scrolling.
        history.replaceState({}, '', '#' + id);
      } else {
        document.location.hash = id;
      }
    }
  });

  //Loads the +1 button
  //var po = document.createElement('script'); po.type = 'text/javascript'; po.async = true;
  //po.src = 'https://apis.google.com/js/plusone.js';
  //var s = document.getElementsByTagName('script')[0]; s.parentNode.insertBefore(po, s);
});
// END of the onload event

function initExpandableNavItems(rootTag) {
  var toggleIcon = $(
      rootTag + ' li.nav-section .nav-section-header .toggle-icon, ' +
      rootTag + ' li.nav-section .nav-section-header a[href="#"]');

  toggleIcon.on('click keypress', function(e) {
    if (e.type == 'keypress' && e.which == 13 || e.type == 'click') {
      doNavToggle(this);
    }
  });

  // Stop expand/collapse behavior when clicking on nav section links
  // (since we're navigating away from the page)
  // This selector captures the first instance of <a>, but not those with "#" as the href.
  $('.nav-section-header').find('a:eq(0)').not('a[href="#"]').click(function(evt) {
    window.location.href = $(this).attr('href');
    return false;
  });
}

function doNavToggle(el) {
  var section = $(el).closest('li.nav-section');
  if (section.hasClass('expanded')) {
    /* hide me and descendants */
    section.find('ul').slideUp(250, function() {
      // remove 'expanded' class from my section and any children
      section.closest('li').removeClass('expanded');
      $('li.nav-section', section).removeClass('expanded');
    });
  } else {
    /* show me */
    // first hide all other siblings
    var $others = $('li.nav-section.expanded', $(el).closest('ul')).not('.sticky');
    $others.removeClass('expanded').children('ul').slideUp(250);

    // now expand me
    section.closest('li').addClass('expanded');
    section.children('ul').slideDown(250);
  }
}

/** Highlight the current page in sidenav, expanding children as appropriate */
function highlightSidenav() {
  // if something is already highlighted, undo it. This is for dynamic navigation (Samples index)
  if ($("ul#nav li.selected").length) {
    unHighlightSidenav();
  }
  // look for URL in sidenav, including the hash
  var $selNavLink = $('#nav').find('a[href="' + mPagePath + location.hash + '"]');

  // If the selNavLink is still empty, look for it without the hash
  if ($selNavLink.length == 0) {
    $selNavLink = $('#nav').find('a[href="' + mPagePath + '"]');
  }

  var $selListItem;
  var breadcrumb = [];

  if ($selNavLink.length) {
    // Find this page's <li> in sidenav and set selected
    $selListItem = $selNavLink.closest('li');
    $selListItem.addClass('selected');

    // Traverse up the tree and expand all parent nav-sections
    $selNavLink.parents('li.nav-section').each(function() {
      $(this).addClass('expanded');
      $(this).children('ul').show();

      var link = $(this).find('a').first();

      if (!$(this).is($selListItem)) {
        breadcrumb.unshift(link)
      }
    });

    $('#nav').scrollIntoView($selNavLink);
  }

  breadcrumb.forEach(function(link) {
    link.dacCrumbs();
  });
}

function unHighlightSidenav() {
  $("ul#nav li.selected").removeClass("selected");
  $('ul#nav li.nav-section.expanded').removeClass('expanded').children('ul').hide();
}

var agent = navigator['userAgent'].toLowerCase();
// If a mobile phone, set flag and do mobile setup
if ((agent.indexOf("mobile") != -1) ||      // android, iphone, ipod
    (agent.indexOf("blackberry") != -1) ||
    (agent.indexOf("webos") != -1) ||
    (agent.indexOf("mini") != -1)) {        // opera mini browsers
  isMobile = true;
}

$(document).ready(function() {
  $("pre:not(.no-pretty-print)").addClass("prettyprint");
  prettyPrint();
});

/* Show popup dialogs */
function showDialog(id) {
  $dialog = $("#" + id);
  $dialog.prepend('<div class="box-border"><div class="top"> <div class="left"></div> <div class="right"></div></div><div class="bottom"> <div class="left"></div> <div class="right"></div> </div> </div>');
  $dialog.wrapInner('<div/>');
  $dialog.removeClass("hide");
}

/* #########    COOKIES!     ########## */

function readCookie(cookie) {
  var myCookie = cookie_namespace + "_" + cookie + "=";
  if (document.cookie) {
    var index = document.cookie.indexOf(myCookie);
    if (index != -1) {
      var valStart = index + myCookie.length;
      var valEnd = document.cookie.indexOf(";", valStart);
      if (valEnd == -1) {
        valEnd = document.cookie.length;
      }
      var val = document.cookie.substring(valStart, valEnd);
      return val;
    }
  }
  return 0;
}

function writeCookie(cookie, val, section) {
  if (val == undefined) return;
  section = section == null ? "_" : "_" + section + "_";
  var age = 2 * 365 * 24 * 60 * 60; // set max-age to 2 years
  var cookieValue = cookie_namespace + section + cookie + "=" + val +
                    "; max-age=" + age + "; path=/";
  document.cookie = cookieValue;
}

/* #########     END COOKIES!     ########## */

/*
 * Manages secion card states and nav resize to conclude loading
 */
(function() {
  $(document).ready(function() {

    // Stack hover states
    $('.section-card-menu').each(function(index, el) {
      var height = $(el).height();
      $(el).css({height:height + 'px', position:'relative'});
      var $cardInfo = $(el).find('.card-info');

      $cardInfo.css({position: 'absolute', bottom:'0px', left:'0px', right:'0px', overflow:'visible'});
    });

  });

})();

/*      MISC LIBRARY FUNCTIONS     */

function toggle(obj, slide) {
  var ul = $("ul:first", obj);
  var li = ul.parent();
  if (li.hasClass("closed")) {
    if (slide) {
      ul.slideDown("fast");
    } else {
      ul.show();
    }
    li.removeClass("closed");
    li.addClass("open");
    $(".toggle-img", li).attr("title", "hide pages");
  } else {
    ul.slideUp("fast");
    li.removeClass("open");
    li.addClass("closed");
    $(".toggle-img", li).attr("title", "show pages");
  }
}

function buildToggleLists() {
  $(".toggle-list").each(
    function(i) {
      $("div:first", this).append("<a class='toggle-img' href='#' title='show pages' onClick='toggle(this.parentNode.parentNode, true); return false;'></a>");
      $(this).addClass("closed");
    });
}

function hideNestedItems(list, toggle) {
  $list = $(list);
  // hide nested lists
  if ($list.hasClass('showing')) {
    $("li ol", $list).hide('fast');
    $list.removeClass('showing');
  // show nested lists
  } else {
    $("li ol", $list).show('fast');
    $list.addClass('showing');
  }
  $(".more,.less", $(toggle)).toggle();
}

/* Call this to add listeners to a <select> element for Studio/Eclipse/Other docs */
function setupIdeDocToggle() {
  $("select.ide").change(function() {
    var selected = $(this).find("option:selected").attr("value");
    $(".select-ide").hide();
    $(".select-ide." + selected).show();

    $("select.ide").val(selected);
  });
}

/* Used to hide and reveal supplemental content, such as long code samples.
   See the companion CSS in android-developer-docs.css */
function toggleContent(obj) {
  var div = $(obj).closest(".toggle-content");
  var toggleMe = $(".toggle-content-toggleme:eq(0)", div);
  if (div.hasClass("closed")) { // if it's closed, open it
    toggleMe.slideDown();
    $(".toggle-content-text:eq(0)", obj).toggle();
    div.removeClass("closed").addClass("open");
    $(".toggle-content-img:eq(0)", div).attr("title", "hide").attr("src", toRoot +
                  "assets/images/styles/disclosure_up.png");
  } else { // if it's open, close it
    toggleMe.slideUp('fast', function() {  // Wait until the animation is done before closing arrow
      $(".toggle-content-text:eq(0)", obj).toggle();
      div.removeClass("open").addClass("closed");
      div.find(".toggle-content").removeClass("open").addClass("closed")
              .find(".toggle-content-toggleme").hide();
      $(".toggle-content-img", div).attr("title", "show").attr("src", toRoot +
                  "assets/images/styles/disclosure_down.png");
    });
  }
  return false;
}

/* New version of expandable content */
function toggleExpandable(link, id) {
  if ($(id).is(':visible')) {
    $(id).slideUp();
    $(link).removeClass('expanded');
  } else {
    $(id).slideDown();
    $(link).addClass('expanded');
  }
}

function hideExpandable(ids) {
  $(ids).slideUp();
  $(ids).prev('h4').find('a.expandable').removeClass('expanded');
}

/*
 *  Slideshow 1.0
 *  Used on /index.html and /develop/index.html for carousel
 *
 *  Sample usage:
 *  HTML -
 *  <div class="slideshow-container">
 *   <a href="" class="slideshow-prev">Prev</a>
 *   <a href="" class="slideshow-next">Next</a>
 *   <ul>
 *       <li class="item"><img src="images/marquee1.jpg"></li>
 *       <li class="item"><img src="images/marquee2.jpg"></li>
 *       <li class="item"><img src="images/marquee3.jpg"></li>
 *       <li class="item"><img src="images/marquee4.jpg"></li>
 *   </ul>
 *  </div>
 *
 *   <script type="text/javascript">
 *   $('.slideshow-container').dacSlideshow({
 *       auto: true,
 *       btnPrev: '.slideshow-prev',
 *       btnNext: '.slideshow-next'
 *   });
 *   </script>
 *
 *  Options:
 *  btnPrev:    optional identifier for previous button
 *  btnNext:    optional identifier for next button
 *  btnPause:   optional identifier for pause button
 *  auto:       whether or not to auto-proceed
 *  speed:      animation speed
 *  autoTime:   time between auto-rotation
 *  easing:     easing function for transition
 *  start:      item to select by default
 *  scroll:     direction to scroll in
 *  pagination: whether or not to include dotted pagination
 *
 */

(function($) {
  $.fn.dacSlideshow = function(o) {

    //Options - see above
    o = $.extend({
      btnPrev:   null,
      btnNext:   null,
      btnPause:  null,
      auto:      true,
      speed:     500,
      autoTime:  12000,
      easing:    null,
      start:     0,
      scroll:    1,
      pagination: true

    }, o || {});

    //Set up a carousel for each
    return this.each(function() {

      var running = false;
      var animCss = o.vertical ? "top" : "left";
      var sizeCss = o.vertical ? "height" : "width";
      var div = $(this);
      var ul = $("ul", div);
      var tLi = $("li", ul);
      var tl = tLi.size();
      var timer = null;

      var li = $("li", ul);
      var itemLength = li.size();
      var curr = o.start;

      li.css({float: o.vertical ? "none" : "left"});
      ul.css({margin: "0", padding: "0", position: "relative", "list-style-type": "none", "z-index": "1"});
      div.css({position: "relative", "z-index": "2", left: "0px"});

      var liSize = o.vertical ? height(li) : width(li);
      var ulSize = liSize * itemLength;
      var divSize = liSize;

      li.css({width: li.width(), height: li.height()});
      ul.css(sizeCss, ulSize + "px").css(animCss, -(curr * liSize));

      div.css(sizeCss, divSize + "px");

      //Pagination
      if (o.pagination) {
        var pagination = $("<div class='pagination'></div>");
        var pag_ul = $("<ul></ul>");
        if (tl > 1) {
          for (var i = 0; i < tl; i++) {
            var li = $("<li>" + i + "</li>");
            pag_ul.append(li);
            if (i == o.start) li.addClass('active');
            li.click(function() {
              go(parseInt($(this).text()));
            })
          }
          pagination.append(pag_ul);
          div.append(pagination);
        }
      }

      //Previous button
      if (o.btnPrev)
             $(o.btnPrev).click(function(e) {
               e.preventDefault();
               return go(curr - o.scroll);
             });

      //Next button
      if (o.btnNext)
             $(o.btnNext).click(function(e) {
               e.preventDefault();
               return go(curr + o.scroll);
             });

      //Pause button
      if (o.btnPause)
             $(o.btnPause).click(function(e) {
               e.preventDefault();
               if ($(this).hasClass('paused')) {
                 startRotateTimer();
               } else {
                 pauseRotateTimer();
               }
             });

      //Auto rotation
      if (o.auto) startRotateTimer();

      function startRotateTimer() {
        clearInterval(timer);
        timer = setInterval(function() {
          if (curr == tl - 1) {
            go(0);
          } else {
            go(curr + o.scroll);
          }
        }, o.autoTime);
        $(o.btnPause).removeClass('paused');
      }

      function pauseRotateTimer() {
        clearInterval(timer);
        $(o.btnPause).addClass('paused');
      }

      //Go to an item
      function go(to) {
        if (!running) {

          if (to < 0) {
            to = itemLength - 1;
          } else if (to > itemLength - 1) {
            to = 0;
          }
          curr = to;

          running = true;

          ul.animate(
              animCss == "left" ? {left: -(curr * liSize)} : {top: -(curr * liSize)} , o.speed, o.easing,
                     function() {
                       running = false;
                     }
                 );

          $(o.btnPrev + "," + o.btnNext).removeClass("disabled");
          $((curr - o.scroll < 0 && o.btnPrev)              ||
             (curr + o.scroll > itemLength && o.btnNext)              ||
             []
           ).addClass("disabled");

          var nav_items = $('li', pagination);
          nav_items.removeClass('active');
          nav_items.eq(to).addClass('active');

        }
        if (o.auto) startRotateTimer();
        return false;
      };
    });
  };

  function css(el, prop) {
    return parseInt($.css(el[0], prop)) || 0;
  };
  function width(el) {
    return el[0].offsetWidth + css(el, 'marginLeft') + css(el, 'marginRight');
  };
  function height(el) {
    return el[0].offsetHeight + css(el, 'marginTop') + css(el, 'marginBottom');
  };

})(jQuery);

/*
 *  dacSlideshow 1.0
 *  Used on develop/index.html for side-sliding tabs
 *
 *  Sample usage:
 *  HTML -
 *  <div class="slideshow-container">
 *   <a href="" class="slideshow-prev">Prev</a>
 *   <a href="" class="slideshow-next">Next</a>
 *   <ul>
 *       <li class="item"><img src="images/marquee1.jpg"></li>
 *       <li class="item"><img src="images/marquee2.jpg"></li>
 *       <li class="item"><img src="images/marquee3.jpg"></li>
 *       <li class="item"><img src="images/marquee4.jpg"></li>
 *   </ul>
 *  </div>
 *
 *   <script type="text/javascript">
 *   $('.slideshow-container').dacSlideshow({
 *       auto: true,
 *       btnPrev: '.slideshow-prev',
 *       btnNext: '.slideshow-next'
 *   });
 *   </script>
 *
 *  Options:
 *  btnPrev:    optional identifier for previous button
 *  btnNext:    optional identifier for next button
 *  auto:       whether or not to auto-proceed
 *  speed:      animation speed
 *  autoTime:   time between auto-rotation
 *  easing:     easing function for transition
 *  start:      item to select by default
 *  scroll:     direction to scroll in
 *  pagination: whether or not to include dotted pagination
 *
 */
(function($) {
  $.fn.dacTabbedList = function(o) {

    //Options - see above
    o = $.extend({
      speed : 250,
      easing: null,
      nav_id: null,
      frame_id: null
    }, o || {});

    //Set up a carousel for each
    return this.each(function() {

      var curr = 0;
      var running = false;
      var animCss = "margin-left";
      var sizeCss = "width";
      var div = $(this);

      var nav = $(o.nav_id, div);
      var nav_li = $("li", nav);
      var nav_size = nav_li.size();
      var frame = div.find(o.frame_id);
      var content_width = $(frame).find('ul').width();
      //Buttons
      $(nav_li).click(function(e) {
           go($(nav_li).index($(this)));
         })

      //Go to an item
      function go(to) {
        if (!running) {
          curr = to;
          running = true;

          frame.animate({'margin-left' : -(curr * content_width)}, o.speed, o.easing,
                     function() {
                       running = false;
                     }
                 );

          nav_li.removeClass('active');
          nav_li.eq(to).addClass('active');

        }
        return false;
      };
    });
  };

  function css(el, prop) {
    return parseInt($.css(el[0], prop)) || 0;
  };
  function width(el) {
    return el[0].offsetWidth + css(el, 'marginLeft') + css(el, 'marginRight');
  };
  function height(el) {
    return el[0].offsetHeight + css(el, 'marginTop') + css(el, 'marginBottom');
  };

})(jQuery);

/* ######################################################## */
/* #################  JAVADOC REFERENCE ################### */
/* ######################################################## */



var API_LEVEL_COOKIE = "api_level";
var minLevel = 1;
var maxLevel = 1;

function buildApiLevelSelector() {
  maxLevel = API_LEVELS.length;
  var userApiLevel = parseInt(readCookie(API_LEVEL_COOKIE));
  userApiLevel = userApiLevel == 0 ? maxLevel : userApiLevel; // If there's no cookie (zero), use the max by default

  minLevel = parseInt($("#doc-api-level").attr("class"));
  // Handle provisional api levels; the provisional level will always be the highest possible level
  // Provisional api levels will also have a length; other stuff that's just missing a level won't,
  // so leave those kinds of entities at the default level of 1 (for example, the R.styleable class)
  if (isNaN(minLevel) && minLevel.length) {
    minLevel = maxLevel;
  }
  var select = $("#apiLevelSelector").html("").change(changeApiLevel);
  for (var i = maxLevel - 1; i >= 0; i--) {
    var option = $("<option />").attr("value", "" + API_LEVELS[i]).append("" + API_LEVELS[i]);
    //  if (API_LEVELS[i] < minLevel) option.addClass("absent"); // always false for strings (codenames)
    select.append(option);
  }

  // get the DOM element and use setAttribute cuz IE6 fails when using jquery .attr('selected',true)
  var selectedLevelItem = $("#apiLevelSelector option[value='" + userApiLevel + "']").get(0);
  selectedLevelItem.setAttribute('selected', true);
}

function changeApiLevel() {
  maxLevel = API_LEVELS.length;
  minLevel = parseInt($('#doc-api-level').attr('class'));
  var selectedLevel = maxLevel;

  selectedLevel = parseInt($("#apiLevelSelector option:selected").val());
  toggleVisisbleApis(selectedLevel, "body");

  writeCookie(API_LEVEL_COOKIE, selectedLevel, null);

  if (selectedLevel < minLevel) {
      // Show the API notice dialog, set number values and button event
      $('#api-unavailable').trigger('modal-open');
      $('#api-unavailable .selected-level').text(selectedLevel);
      $('#api-unavailable .api-level').text(minLevel);
      $('#api-unavailable button.ok').attr('onclick','$("#apiLevelSelector").val("' + minLevel + '");changeApiLevel();');
  }
}

function toggleVisisbleApis(selectedLevel, context) {
  var apis = $(".api", context);
  apis.each(function(i) {
    var obj = $(this);
    var className = obj.attr("class");
    var apiLevelIndex = className.lastIndexOf("-") + 1;
    var apiLevelEndIndex = className.indexOf(" ", apiLevelIndex);
    apiLevelEndIndex = apiLevelEndIndex != -1 ? apiLevelEndIndex : className.length;
    var apiLevel = className.substring(apiLevelIndex, apiLevelEndIndex);
    if (apiLevel.length == 0) { // for odd cases when the since data is actually missing, just bail
      return;
    }
    apiLevel = parseInt(apiLevel);

    // Handle provisional api levels; if this item's level is the provisional one, set it to the max
    var selectedLevelNum = parseInt(selectedLevel)
    var apiLevelNum = parseInt(apiLevel);
    if (isNaN(apiLevelNum)) {
      apiLevelNum = maxLevel;
    }

    // Grey things out that aren't available and give a tooltip title
    if (apiLevelNum > selectedLevelNum) {
      obj.addClass("absent").attr("title", "Requires API Level \"" +
            apiLevel + "\" or higher. To reveal, change the target API level " +
              "above the left navigation.");
    } else obj.removeClass("absent").removeAttr("title");
  });
}

/* #################  SIDENAV TREE VIEW ################### */
/* TODO: eliminate redundancy with non-google functions */
function init_google_navtree(navtree_id, toroot, root_nodes) {
  var me = new Object();
  me.toroot = toroot;
  me.node = new Object();

  me.node.li = document.getElementById(navtree_id);
  if (!me.node.li) {
    return;
  }

  me.node.children_data = root_nodes;
  me.node.children = new Array();
  me.node.children_ul = document.createElement("ul");
  me.node.get_children_ul = function() { return me.node.children_ul; };
  //me.node.children_ul.className = "children_ul";
  me.node.li.appendChild(me.node.children_ul);
  me.node.depth = 0;

  get_google_node(me, me.node);
}

function new_google_node(me, mom, text, link, children_data, api_level) {
  var node = new Object();
  var child;
  node.children = Array();
  node.children_data = children_data;
  node.depth = mom.depth + 1;
  node.get_children_ul = function() {
      if (!node.children_ul) {
        node.children_ul = document.createElement("ul");
        node.children_ul.className = "tree-list-children";
        node.li.appendChild(node.children_ul);
      }
      return node.children_ul;
    };
  node.li = document.createElement("li");

  mom.get_children_ul().appendChild(node.li);

  if (link) {
    child = document.createElement("a");

  } else {
    child = document.createElement("span");
    child.className = "tree-list-subtitle";

  }
  if (children_data != null) {
    node.li.className = "nav-section";
    node.label_div = document.createElement("div");
    node.label_div.className = "nav-section-header-ref";
    node.li.appendChild(node.label_div);
    get_google_node(me, node);
    node.label_div.appendChild(child);
  } else {
    node.li.appendChild(child);
  }
  if (link) {
    child.href = me.toroot + link;
  }
  node.label = document.createTextNode(text);
  child.appendChild(node.label);

  node.children_ul = null;

  return node;
}

function get_google_node(me, mom) {
  mom.children_visited = true;
  var linkText;
  for (var i in mom.children_data) {
    var node_data = mom.children_data[i];
    linkText = node_data[0];

    if (linkText.match("^" + "com.google.android") == "com.google.android") {
      linkText = linkText.substr(19, linkText.length);
    }
    mom.children[i] = new_google_node(me, mom, linkText, node_data[1],
        node_data[2], node_data[3]);
  }
}

/****** NEW version of script to build google and sample navs dynamically ******/
// TODO: update Google reference docs to tolerate this new implementation

var NODE_NAME = 0;
var NODE_HREF = 1;
var NODE_GROUP = 2;
var NODE_TAGS = 3;
var NODE_CHILDREN = 4;

function init_google_navtree2(navtree_id, data) {
  var $containerUl = $("#" + navtree_id);
  for (var i in data) {
    var node_data = data[i];
    $containerUl.append(new_google_node2(node_data));
  }

  // Make all third-generation list items 'sticky' to prevent them from collapsing
  $containerUl.find('li li li.nav-section').addClass('sticky');

  initExpandableNavItems("#" + navtree_id);
}

function new_google_node2(node_data) {
  var linkText = node_data[NODE_NAME];
  if (linkText.match("^" + "com.google.android") == "com.google.android") {
    linkText = linkText.substr(19, linkText.length);
  }
  var $li = $('<li>');
  var $a;
  if (node_data[NODE_HREF] != null) {
    $a = $('<a href="' + toRoot + node_data[NODE_HREF] + '" title="' + linkText + '" >' +
        linkText + '</a>');
  } else {
    $a = $('<a href="#" onclick="return false;" title="' + linkText + '" >' +
        linkText + '/</a>');
  }
  var $childUl = $('<ul>');
  if (node_data[NODE_CHILDREN] != null) {
    $li.addClass("nav-section");
    $a = $('<div class="nav-section-header">').append($a);
    if (node_data[NODE_HREF] == null) $a.addClass('empty');

    for (var i in node_data[NODE_CHILDREN]) {
      var child_node_data = node_data[NODE_CHILDREN][i];
      $childUl.append(new_google_node2(child_node_data));
    }
    $li.append($childUl);
  }
  $li.prepend($a);

  return $li;
}

function showGoogleRefTree() {
  init_default_google_navtree(toRoot);
  init_default_gcm_navtree(toRoot);
}

function init_default_google_navtree(toroot) {
  // load json file for navtree data
  $.getScript(toRoot + 'gms_navtree_data.js', function(data, textStatus, jqxhr) {
    // when the file is loaded, initialize the tree
    if (jqxhr.status === 200) {
      init_google_navtree("gms-tree-list", toroot, GMS_NAVTREE_DATA);
      highlightSidenav();
    }
  });
}

function init_default_gcm_navtree(toroot) {
  // load json file for navtree data
  $.getScript(toRoot + 'gcm_navtree_data.js', function(data, textStatus, jqxhr) {
    // when the file is loaded, initialize the tree
    if (jqxhr.status === 200) {
      init_google_navtree("gcm-tree-list", toroot, GCM_NAVTREE_DATA);
      highlightSidenav();
    }
  });
}

/* TOGGLE INHERITED MEMBERS */

/* Toggle an inherited class (arrow toggle)
 * @param linkObj  The link that was clicked.
 * @param expand  'true' to ensure it's expanded. 'false' to ensure it's closed.
 *                'null' to simply toggle.
 */
function toggleInherited(linkObj, expand) {
  var base = linkObj.getAttribute("id");
  var list = document.getElementById(base + "-list");
  var summary = document.getElementById(base + "-summary");
  var trigger = document.getElementById(base + "-trigger");
  var a = $(linkObj);
  if ((expand == null && a.hasClass("closed")) || expand) {
    list.style.display = "none";
    summary.style.display = "block";
    trigger.src = toRoot + "assets/images/styles/disclosure_up.png";
    a.removeClass("closed");
    a.addClass("opened");
  } else if ((expand == null && a.hasClass("opened")) || (expand == false)) {
    list.style.display = "block";
    summary.style.display = "none";
    trigger.src = toRoot + "assets/images/styles/disclosure_down.png";
    a.removeClass("opened");
    a.addClass("closed");
  }
  return false;
}

/* Toggle all inherited classes in a single table (e.g. all inherited methods)
 * @param linkObj  The link that was clicked.
 * @param expand  'true' to ensure it's expanded. 'false' to ensure it's closed.
 *                'null' to simply toggle.
 */
function toggleAllInherited(linkObj, expand) {
  var a = $(linkObj);
  var table = $(a.parent().parent().parent()); // ugly way to get table/tbody
  var expandos = $(".jd-expando-trigger", table);
  if ((expand == null && a.text() == "[Expand]") || expand) {
    expandos.each(function(i) {
      toggleInherited(this, true);
    });
    a.text("[Collapse]");
  } else if ((expand == null && a.text() == "[Collapse]") || (expand == false)) {
    expandos.each(function(i) {
      toggleInherited(this, false);
    });
    a.text("[Expand]");
  }
  return false;
}

/* Toggle all inherited members in the class (link in the class title)
 */
function toggleAllClassInherited() {
  var a = $("#toggleAllClassInherited"); // get toggle link from class title
  var toggles = $(".toggle-all", $("#body-content"));
  if (a.text() == "[Expand All]") {
    toggles.each(function(i) {
      toggleAllInherited(this, true);
    });
    a.text("[Collapse All]");
  } else {
    toggles.each(function(i) {
      toggleAllInherited(this, false);
    });
    a.text("[Expand All]");
  }
  return false;
}

/* Expand all inherited members in the class. Used when initiating page search */
function ensureAllInheritedExpanded() {
  var toggles = $(".toggle-all", $("#body-content"));
  toggles.each(function(i) {
    toggleAllInherited(this, true);
  });
  $("#toggleAllClassInherited").text("[Collapse All]");
}

/* HANDLE KEY EVENTS
 * - Listen for Ctrl+F (Cmd on Mac) and expand all inherited members (to aid page search)
 */
var agent = navigator['userAgent'].toLowerCase();
var mac = agent.indexOf("macintosh") != -1;

$(document).keydown(function(e) {
  var control = mac ? e.metaKey && !e.ctrlKey : e.ctrlKey; // get ctrl key
  if (control && e.which == 70) {  // 70 is "F"
    ensureAllInheritedExpanded();
  }
});

/* On-demand functions */

/** Move sample code line numbers out of PRE block and into non-copyable column */
function initCodeLineNumbers() {
  var numbers = $("#codesample-block a.number");
  if (numbers.length) {
    $("#codesample-line-numbers").removeClass("hidden").append(numbers);
  }

  $(document).ready(function() {
    // select entire line when clicked
    $("span.code-line").click(function() {
      if (!shifted) {
        selectText(this);
      }
    });
    // invoke line link on double click
    $(".code-line").dblclick(function() {
      document.location.hash = $(this).attr('id');
    });
    // highlight the line when hovering on the number
    $("#codesample-line-numbers a.number").mouseover(function() {
      var id = $(this).attr('href');
      $(id).css('background', '#e7e7e7');
    });
    $("#codesample-line-numbers a.number").mouseout(function() {
      var id = $(this).attr('href');
      $(id).css('background', 'none');
    });
  });
}

// create SHIFT key binder to avoid the selectText method when selecting multiple lines
var shifted = false;
$(document).bind('keyup keydown', function(e) {
  shifted = e.shiftKey; return true;
});

// courtesy of jasonedelman.com
function selectText(element) {
  var doc = document      ,
        range, selection
  ;
  if (doc.body.createTextRange) { //ms
    range = doc.body.createTextRange();
    range.moveToElementText(element);
    range.select();
  } else if (window.getSelection) { //all others
    selection = window.getSelection();
    range = doc.createRange();
    range.selectNodeContents(element);
    selection.removeAllRanges();
    selection.addRange(range);
  }
}

/** Display links and other information about samples that match the
    group specified by the URL */
function showSamples() {
  var group = $("#samples").attr('class');
  $("#samples").html("<p>Here are some samples for <b>" + group + "</b> apps:</p>");

  var $ul = $("<ul>");
  $selectedLi = $("#nav li.selected");

  $selectedLi.children("ul").children("li").each(function() {
    var $li = $("<li>").append($(this).find("a").first().clone());
    var $samplesLink = $li.find("a");
    if ($samplesLink.text().endsWith('/')) {
      $samplesLink.text($samplesLink.text().slice(0,-1));
    }
    $ul.append($li);
  });

  $("#samples").append($ul);

}

/* ########################################################## */
/* ###################  RESOURCE CARDS  ##################### */
/* ########################################################## */

/** Handle resource queries, collections, and grids (sections). Requires
    jd_tag_helpers.js and the *_unified_data.js to be loaded. */

(function() {
  $(document).ready(function() {
    // Need to initialize hero carousel before other sections for dedupe
    // to work correctly.
    $('[data-carousel-query]').dacCarouselQuery();

    // Iterate over all instances and initialize a resource widget.
    $('.resource-widget').resourceWidget();
  });

  $.fn.widgetOptions = function() {
    return {
      cardSizes: (this.data('cardsizes') || '').split(','),
      maxResults: parseInt(this.data('maxresults'), 10) || Infinity,
      initialResults: this.data('initialResults'),
      itemsPerPage: this.data('itemsPerPage'),
      sortOrder: this.data('sortorder'),
      query: this.data('query'),
      section: this.data('section'),
      /* Added by LFL 6/6/14 */
      resourceStyle: this.data('resourcestyle') || 'card',
      stackSort: this.data('stacksort') || 'true',
      // For filter based resources
      allowDuplicates: this.data('allow-duplicates') || 'false'
    };
  };

  $.fn.deprecateOldGridStyles = function() {
    var m = this.get(0).className.match(/\bcol-(\d+)\b/);
    if (m && !this.is('.cols > *')) {
      this.removeClass('col-' + m[1]);
    }
    return this;
  }

  /*
   * Three types of resource layouts:
   * Flow - Uses a fixed row-height flow using float left style.
   * Carousel - Single card slideshow all same dimension absolute.
   * Stack - Uses fixed columns and flexible element height.
   */
  function initResourceWidget(widget, resources, opts) {
    var $widget = $(widget).deprecateOldGridStyles();
    var isFlow = $widget.hasClass('resource-flow-layout');
    var isCarousel = $widget.hasClass('resource-carousel-layout');
    var isStack = $widget.hasClass('resource-stack-layout');

    opts = opts || $widget.widgetOptions();
    resources = resources || metadata.query(opts);

    if (opts.maxResults !== undefined) {
      resources = resources.slice(0, opts.maxResults);
    }

    if (isFlow) {
      drawResourcesFlowWidget($widget, opts, resources);
    } else if (isCarousel) {
      drawResourcesCarouselWidget($widget, opts, resources);
    } else if (isStack) {
      opts.numStacks = $widget.data('numstacks');
      drawResourcesStackWidget($widget, opts, resources);
    }
  }

  $.fn.resourceWidget = function(resources, options) {
    return this.each(function() {
      initResourceWidget(this, resources, options);
    });
  };

  /* Initializes a Resource Carousel Widget */
  function drawResourcesCarouselWidget($widget, opts, resources) {
    $widget.empty();
    var plusone = false; // stop showing plusone buttons on cards

    $widget.addClass('resource-card slideshow-container')
      .append($('<a>').addClass('slideshow-prev').text('Prev'))
      .append($('<a>').addClass('slideshow-next').text('Next'));

    var css = {'width': $widget.width() + 'px',
                'height': $widget.height() + 'px'};

    var $ul = $('<ul>');

    for (var i = 0; i < resources.length; ++i) {
      var $card = $('<a>')
        .attr('href', cleanUrl(resources[i].url))
        .decorateResourceCard(resources[i], plusone);

      $('<li>').css(css)
          .append($card)
          .appendTo($ul);
    }

    $('<div>').addClass('frame')
      .append($ul)
      .appendTo($widget);

    $widget.dacSlideshow({
      auto: true,
      btnPrev: '.slideshow-prev',
      btnNext: '.slideshow-next'
    });
  }

  /* Initializes a Resource Card Stack Widget (column-based layout)
     Modified by LFL 6/6/14
   */
  function drawResourcesStackWidget($widget, opts, resources, sections) {
    // Don't empty widget, grab all items inside since they will be the first
    // items stacked, followed by the resource query
    var plusone = false; // stop showing plusone buttons on cards
    var cards = $widget.find('.resource-card').detach().toArray();
    var numStacks = opts.numStacks || 1;
    var $stacks = [];

    for (var i = 0; i < numStacks; ++i) {
      $stacks[i] = $('<div>').addClass('resource-card-stack')
          .appendTo($widget);
    }

    var sectionResources = [];

    // Extract any subsections that are actually resource cards
    if (sections) {
      for (i = 0; i < sections.length; ++i) {
        if (!sections[i].sections || !sections[i].sections.length) {
          // Render it as a resource card
          sectionResources.push(
            $('<a>')
              .addClass('resource-card section-card')
              .attr('href', cleanUrl(sections[i].resource.url))
              .decorateResourceCard(sections[i].resource, plusone)[0]
          );

        } else {
          cards.push(
            $('<div>')
              .addClass('resource-card section-card-menu')
              .decorateResourceSection(sections[i], plusone)[0]
          );
        }
      }
    }

    cards = cards.concat(sectionResources);

    for (i = 0; i < resources.length; ++i) {
      var $card = createResourceElement(resources[i], opts);

      if (opts.resourceStyle.indexOf('related') > -1) {
        $card.addClass('related-card');
      }

      cards.push($card[0]);
    }

    if (opts.stackSort !== 'false') {
      for (i = 0; i < cards.length; ++i) {
        // Find the stack with the shortest height, but give preference to
        // left to right order.
        var minHeight = $stacks[0].height();
        var minIndex = 0;

        for (var j = 1; j < numStacks; ++j) {
          var height = $stacks[j].height();
          if (height < minHeight - 45) {
            minHeight = height;
            minIndex = j;
          }
        }

        $stacks[minIndex].append($(cards[i]));
      }
    }
  }

  /*
    Create a resource card using the given resource object and a list of html
     configured options. Returns a jquery object containing the element.
  */
  function createResourceElement(resource, opts, plusone) {
    var $el;

    // The difference here is that generic cards are not entirely clickable
    // so its a div instead of an a tag, also the generic one is not given
    // the resource-card class so it appears with a transparent background
    // and can be styled in whatever way the css setup.
    if (opts.resourceStyle === 'generic') {
      $el = $('<div>')
        .addClass('resource')
        .attr('href', cleanUrl(resource.url))
        .decorateResource(resource, opts);
    } else {
      var cls = 'resource resource-card';

      $el = $('<a>')
        .addClass(cls)
        .attr('href', cleanUrl(resource.url))
        .decorateResourceCard(resource, plusone);
    }

    return $el;
  }

  function createResponsiveFlowColumn(cardSize) {
    var cardWidth = parseInt(cardSize.match(/(\d+)/)[1], 10);
    var column = $('<div>').addClass('col-' + (cardWidth / 3) + 'of6');
    if (cardWidth < 9) {
      column.addClass('col-tablet-1of2');
    } else if (cardWidth > 9 && cardWidth < 18) {
      column.addClass('col-tablet-1of1');
    }
    if (cardWidth < 18) {
      column.addClass('col-mobile-1of1');
    }
    return column;
  }

  /* Initializes a flow widget, see distribute.scss for generating accompanying css */
  function drawResourcesFlowWidget($widget, opts, resources) {
    // We'll be doing our own modifications to opts.
    opts = $.extend({}, opts);

    $widget.empty().addClass('cols');
    if (opts.itemsPerPage) {
      $('<div class="col-1of1 dac-section-links dac-text-center">')
        .append(
          $('<div class="dac-section-link dac-show-less" data-toggle="show-less">Less<i class="dac-sprite dac-auto-unfold-less"></i></div>'),
          $('<div class="dac-section-link dac-show-more" data-toggle="show-more">More<i class="dac-sprite dac-auto-unfold-more"></i></div>')
        )
        .appendTo($widget);
    }

    $widget.data('options.resourceflow', opts);
    $widget.data('resources.resourceflow', resources);

    drawResourceFlowPage($widget, opts, resources);
  }

  function drawResourceFlowPage($widget, opts, resources) {
    var cardSizes = opts.cardSizes || ['6x6']; // 2015-08-09: dynamic card sizes are deprecated
    var i = opts.currentIndex || 0;
    var j = 0;
    var plusone = false; // stop showing plusone buttons on cards
    var firstPage = i === 0;
    var initialResults = opts.initialResults || opts.itemsPerPage || resources.length;
    var max = firstPage ? initialResults : i + opts.itemsPerPage;
    max = Math.min(resources.length, max);

    var page = $('<div class="resource-flow-page">');
    if (opts.itemsPerPage) {
      $widget.find('.dac-section-links').before(page);
    } else {
      $widget.append(page);
    }

    while (i < max) {
      var cardSize = cardSizes[j++ % cardSizes.length];
      cardSize = cardSize.replace(/^\s+|\s+$/, '');

      var column = createResponsiveFlowColumn(cardSize).appendTo(page);

      // A stack has a third dimension which is the number of stacked items
      var isStack = cardSize.match(/(\d+)x(\d+)x(\d+)/);
      var stackCount = 0;
      var $stackDiv = null;

      if (isStack) {
        // Create a stack container which should have the dimensions defined
        // by the product of the items inside.
        $stackDiv = $('<div>').addClass('resource-card-stack resource-card-' + isStack[1] +
          'x' + isStack[2] * isStack[3]) .appendTo(column);
      }

      // Build each stack item or just a single item
      do {
        var resource = resources[i];

        var $card = createResourceElement(resources[i], opts, plusone);

        $card.addClass('resource-card-' + cardSize +
          ' resource-card-' + resource.type.toLowerCase());

        if (isStack) {
          $card.addClass('resource-card-' + isStack[1] + 'x' + isStack[2]);
          if (++stackCount === parseInt(isStack[3])) {
            $card.addClass('resource-card-row-stack-last');
            stackCount = 0;
          }
        } else {
          stackCount = 0;
        }

        $card.appendTo($stackDiv || column);

      } while (++i < max && stackCount > 0);

      // Record number of pages viewed in analytics.
      if (!firstPage) {
        var clicks = Math.ceil((i - initialResults) / opts.itemsPerPage);
        devsite.analytics.trackAnalyticsEvent('event',
            'Cards', 'Click More', clicks);
      }
    }

    opts.currentIndex = i;
    $widget.toggleClass('dac-has-more', i < resources.length);
    $widget.toggleClass('dac-has-less', !firstPage);

    $widget.trigger('dac:domchange');
    if (opts.onRenderPage) {
      opts.onRenderPage(page);
    }
  }

  function drawResourceFlowReset($widget, opts, resources) {
    $widget.find('.resource-flow-page')
        .slice(1)
        .remove();
    $widget.toggleClass('dac-has-more', true);
    $widget.toggleClass('dac-has-less', false);

    opts.currentIndex = Math.min(opts.initialResults, resources.length);
    devsite.analytics.trackAnalyticsEvent('event', 'Cards', 'Click Less');
  }

  /* A decorator for event functions which finds the surrounding widget and it's options */
  function wrapWithWidget(func) {
    return function(e) {
      if (e) e.preventDefault();

      var $widget = $(this).closest('.resource-flow-layout');
      var opts = $widget.data('options.resourceflow');
      var resources = $widget.data('resources.resourceflow');
      func($widget, opts, resources);
    };
  }

  /* Build a site map of resources using a section as a root. */
  function buildSectionList(opts) {
    if (opts.section && SECTION_BY_ID[opts.section]) {
      return SECTION_BY_ID[opts.section].sections || [];
    }
    return [];
  }

  function cleanUrl(url) {
    if (url && url.indexOf('//') === -1) {
      url = toRoot + url;
    }

    return url;
  }

  // Delegated events for resources.
  $(document).on('click', '.resource-flow-layout [data-toggle="show-more"]', wrapWithWidget(drawResourceFlowPage));
  $(document).on('click', '.resource-flow-layout [data-toggle="show-less"]', wrapWithWidget(drawResourceFlowReset));
})();

(function($) {
  // A mapping from category and type values to new values or human presentable strings.
  var SECTION_MAP = {
    googleplay: 'google play'
  };

  /*
    Utility method for creating dom for the description area of a card.
    Used in decorateResourceCard and decorateResource.
  */
  function buildResourceCardDescription(resource, plusone) {
    var $description = $('<div>').addClass('description ellipsis');

    $description.append($('<div>').addClass('text').html(resource.summary));

    if (resource.cta) {
      $description.append($('<a>').addClass('cta').html(resource.cta));
    }

    if (plusone) {
      var plusurl = resource.url.indexOf("//") > -1 ? resource.url :
        "//developer.android.com/" + resource.url;

      $description.append($('<div>').addClass('util')
        .append($('<div>').addClass('g-plusone')
          .attr('data-size', 'small')
          .attr('data-align', 'right')
          .attr('data-href', plusurl)));
    }

    return $description;
  }

  /* Simple jquery function to create dom for a standard resource card */
  $.fn.decorateResourceCard = function(resource, plusone) {
    var section = resource.category || resource.type;
    section = (SECTION_MAP[section] || section).toLowerCase();
    var imgUrl = resource.image ||
      'assets/images/resource-card-default-android.jpg';

    if (imgUrl.indexOf('//') === -1) {
      imgUrl = toRoot + imgUrl;
    }

    if (resource.type === 'youtube' || resource.type === 'video') {
      $('<div>').addClass('play-button')
        .append($('<i class="dac-sprite dac-play-white">'))
        .appendTo(this);
    }

    $('<div>').addClass('card-bg')
      .css('background-image', 'url(' + (imgUrl || toRoot +
        'assets/images/resource-card-default-android.jpg') + ')')
      .appendTo(this);

    $('<div>').addClass('card-info' + (!resource.summary ? ' empty-desc' : ''))
      .append($('<div>').addClass('section').text(section))
      .append($('<div>').addClass('title' + (resource.title_highlighted ? ' highlighted' : ''))
        .html(resource.title_highlighted || resource.title))
      .append(buildResourceCardDescription(resource, plusone))
      .appendTo(this);

    return this;
  };

  /* Simple jquery function to create dom for a resource section card (menu) */
  $.fn.decorateResourceSection = function(section, plusone) {
    var resource = section.resource;
    //keep url clean for matching and offline mode handling
    var urlPrefix = resource.image.indexOf("//") > -1 ? "" : toRoot;
    var $base = $('<a>')
        .addClass('card-bg')
        .attr('href', resource.url)
        .append($('<div>').addClass('card-section-icon')
          .append($('<div>').addClass('icon'))
          .append($('<div>').addClass('section').html(resource.title)))
      .appendTo(this);

    var $cardInfo = $('<div>').addClass('card-info').appendTo(this);

    if (section.sections && section.sections.length) {
      // Recurse the section sub-tree to find a resource image.
      var stack = [section];

      while (stack.length) {
        if (stack[0].resource.image) {
          $base.css('background-image', 'url(' + urlPrefix + stack[0].resource.image + ')');
          break;
        }

        if (stack[0].sections) {
          stack = stack.concat(stack[0].sections);
        }

        stack.shift();
      }

      var $ul = $('<ul>')
        .appendTo($cardInfo);

      var max = section.sections.length > 3 ? 3 : section.sections.length;

      for (var i = 0; i < max; ++i) {

        var subResource = section.sections[i];
        if (!plusone) {
          $('<li>')
            .append($('<a>').attr('href', subResource.url)
              .append($('<div>').addClass('title').html(subResource.title))
              .append($('<div>').addClass('description ellipsis')
                .append($('<div>').addClass('text').html(subResource.summary))
                .append($('<div>').addClass('util'))))
          .appendTo($ul);
        } else {
          $('<li>')
            .append($('<a>').attr('href', subResource.url)
              .append($('<div>').addClass('title').html(subResource.title))
              .append($('<div>').addClass('description ellipsis')
                .append($('<div>').addClass('text').html(subResource.summary))
                .append($('<div>').addClass('util')
                  .append($('<div>').addClass('g-plusone')
                    .attr('data-size', 'small')
                    .attr('data-align', 'right')
                    .attr('data-href', resource.url)))))
          .appendTo($ul);
        }
      }

      // Add a more row
      if (max < section.sections.length) {
        $('<li>')
          .append($('<a>').attr('href', resource.url)
            .append($('<div>')
              .addClass('title')
              .text('More')))
        .appendTo($ul);
      }
    } else {
      // No sub-resources, just render description?
    }

    return this;
  };

  /* Render other types of resource styles that are not cards. */
  $.fn.decorateResource = function(resource, opts) {
    var imgUrl = resource.image ||
      'assets/images/resource-card-default-android.jpg';
    var linkUrl = resource.url;

    if (imgUrl.indexOf('//') === -1) {
      imgUrl = toRoot + imgUrl;
    }

    if (linkUrl && linkUrl.indexOf('//') === -1) {
      linkUrl = toRoot + linkUrl;
    }

    $(this).append(
      $('<div>').addClass('image')
        .css('background-image', 'url(' + imgUrl + ')'),
      $('<div>').addClass('info').append(
        $('<h4>').addClass('title').html(resource.title_highlighted || resource.title),
        $('<p>').addClass('summary').html(resource.summary),
        $('<a>').attr('href', linkUrl).addClass('cta').html('Learn More')
      )
    );

    return this;
  };
})(jQuery);

/*
  Fullscreen Carousel

  The following allows for an area at the top of the page that takes over the
  entire browser height except for its top offset and an optional bottom
  padding specified as a data attribute.

  HTML:

  <div class="fullscreen-carousel">
    <div class="fullscreen-carousel-content">
      <!-- content here -->
    </div>
    <div class="fullscreen-carousel-content">
      <!-- content here -->
    </div>

    etc ...

  </div>

  Control over how the carousel takes over the screen can mostly be defined in
  a css file. Setting min-height on the .fullscreen-carousel-content elements
  will prevent them from shrinking to far vertically when the browser is very
  short, and setting max-height on the .fullscreen-carousel itself will prevent
  the area from becoming to long in the case that the browser is stretched very
  tall.

  There is limited functionality for having multiple sections since that request
  was removed, but it is possible to add .next-arrow and .prev-arrow elements to
  scroll between multiple content areas.
*/

(function() {
  $(document).ready(function() {
    $('.fullscreen-carousel').each(function() {
      initWidget(this);
    });
  });

  function initWidget(widget) {
    var $widget = $(widget);

    var topOffset = $widget.offset().top;
    var padBottom = parseInt($widget.data('paddingbottom')) || 0;
    var maxHeight = 0;
    var minHeight = 0;
    var $content = $widget.find('.fullscreen-carousel-content');
    var $nextArrow = $widget.find('.next-arrow');
    var $prevArrow = $widget.find('.prev-arrow');
    var $curSection = $($content[0]);

    if ($content.length <= 1) {
      $nextArrow.hide();
      $prevArrow.hide();
    } else {
      $nextArrow.click(function() {
        var index = ($content.index($curSection) + 1);
        $curSection.hide();
        $curSection = $($content[index >= $content.length ? 0 : index]);
        $curSection.show();
      });

      $prevArrow.click(function() {
        var index = ($content.index($curSection) - 1);
        $curSection.hide();
        $curSection = $($content[index < 0 ? $content.length - 1 : 0]);
        $curSection.show();
      });
    }

    // Just hide all content sections except first.
    $content.each(function(index) {
      if ($(this).height() > minHeight) minHeight = $(this).height();
      $(this).css({position: 'absolute',  display: index > 0 ? 'none' : ''});
    });

    // Register for changes to window size, and trigger.
    $(window).resize(resizeWidget);
    resizeWidget();

    function resizeWidget() {
      var height = $(window).height() - topOffset - padBottom;
      $widget.width($(window).width());
      $widget.height(height < minHeight ? minHeight :
        (maxHeight && height > maxHeight ? maxHeight : height));
    }
  }
})();

/*
  Tab Carousel

  The following allows tab widgets to be installed via the html below. Each
  tab content section should have a data-tab attribute matching one of the
  nav items'. Also each tab content section should have a width matching the
  tab carousel.

  HTML:

  <div class="tab-carousel">
    <ul class="tab-nav">
      <li><a href="#" data-tab="handsets">Handsets</a>
      <li><a href="#" data-tab="wearable">Wearable</a>
      <li><a href="#" data-tab="tv">TV</a>
    </ul>

    <div class="tab-carousel-content">
      <div data-tab="handsets">
        <!--Full width content here-->
      </div>

      <div data-tab="wearable">
        <!--Full width content here-->
      </div>

      <div data-tab="tv">
        <!--Full width content here-->
      </div>
    </div>
  </div>

*/
(function() {
  $(document).ready(function() {
    $('.tab-carousel').each(function() {
      initWidget(this);
    });
  });

  function initWidget(widget) {
    var $widget = $(widget);
    var $nav = $widget.find('.tab-nav');
    var $anchors = $nav.find('[data-tab]');
    var $li = $nav.find('li');
    var $contentContainer = $widget.find('.tab-carousel-content');
    var $tabs = $contentContainer.find('[data-tab]');
    var $curTab = $($tabs[0]); // Current tab is first tab.
    var width = $widget.width();

    // Setup nav interactivity.
    $anchors.click(function(evt) {
      evt.preventDefault();
      var query = '[data-tab=' + $(this).data('tab') + ']';
      transitionWidget($tabs.filter(query));
    });

    // Add highlight for navigation on first item.
    var $highlight = $('<div>').addClass('highlight')
      .css({left:$li.position().left + 'px', width:$li.outerWidth() + 'px'})
      .appendTo($nav);

    // Store height since we will change contents to absolute.
    $contentContainer.height($contentContainer.height());

    // Absolutely position tabs so they're ready for transition.
    $tabs.each(function(index) {
      $(this).css({position: 'absolute', left: index > 0 ? width + 'px' : '0'});
    });

    function transitionWidget($toTab) {
      if (!$curTab.is($toTab)) {
        var curIndex = $tabs.index($curTab[0]);
        var toIndex = $tabs.index($toTab[0]);
        var dir = toIndex > curIndex ? 1 : -1;

        // Animate content sections.
        $toTab.css({left:(width * dir) + 'px'});
        $curTab.animate({left:(width * -dir) + 'px'});
        $toTab.animate({left:'0'});

        // Animate navigation highlight.
        $highlight.animate({left:$($li[toIndex]).position().left + 'px',
          width:$($li[toIndex]).outerWidth() + 'px'})

        // Store new current section.
        $curTab = $toTab;
      }
    }
  }
})();

/**
 * Auto TOC
 *
 * Upgrades h2s on the page to have a rule and be toggle-able on mobile.
 */
(function($) {
  var upgraded = false;
  var h2Titles;

  function initWidget() {
    // add HRs below all H2s (except for a few other h2 variants)
    // Consider doing this with css instead.
    h2Titles = $('h2').not('#qv h2, #tb h2, .sidebox h2, #devdoc-nav h2, h2.norule');
    h2Titles.css({paddingBottom:0}).after('<hr/>');

    // Exit early if on older browser.
    if (!window.matchMedia) {
      return;
    }

    // Only run logic in mobile layout.
    var query = window.matchMedia('(max-width: 719px)');
    if (query.matches) {
      makeTogglable();
    } else {
      query.addListener(makeTogglable);
    }
  }

  function makeTogglable() {
    // Only run this logic once.
    if (upgraded) { return; }
    upgraded = true;

    // Only make content h2s togglable.
    var contentTitles = h2Titles.filter('#jd-content *');

    // If there are more than 1
    if (contentTitles.size() < 2) {
      return;
    }

    contentTitles.each(function() {
      // Find all the relevant nodes.
      var $title = $(this);
      var $hr = $title.next();
      var $contents = allNextUntil($hr[0], 'h2, .next-docs');
      var $section = $($title)
        .add($hr)
        .add($title.prev('a[name]'))
        .add($contents);
      var $anchor = $section.first().prev();
      var anchorMethod = 'after';
      if ($anchor.length === 0) {
        $anchor = $title.parent();
        anchorMethod = 'prepend';
      }

      // Some h2s are in their own container making it pretty hard to find the end, so skip.
      if ($contents.length === 0) {
        return;
      }

      // Remove from DOM before messing with it. DOM is slow!
      $section.detach();

      // Add mobile-only expand arrows.
      $title.prepend('<span class="dac-visible-mobile-inline-block">' +
          '<i class="dac-toggle-expand dac-sprite dac-expand-more-black"></i>' +
          '<i class="dac-toggle-collapse dac-sprite dac-expand-less-black"></i>' +
          '</span>')
        .attr('data-toggle', 'section');

      // Wrap in magic markup.
      $section = $section.wrapAll('<div class="dac-toggle dac-mobile">').parent();

      // extra div used for max-height calculation.
      $contents.wrapAll('<div class="dac-toggle-content dac-expand"><div>');

      // Pre-expand section if requested.
      if ($title.hasClass('is-expanded')) {
        $section.addClass('is-expanded');
      }

      // Pre-expand section if targetted by hash.
      if (location.hash && $section.find(location.hash).length) {
        $section.addClass('is-expanded');
      }

      // Add it back to the dom.
      $anchor[anchorMethod].call($anchor, $section);
    });
  }

  // Similar to $.fn.nextUntil() except we need all nodes, jQuery skips text nodes.
  function allNextUntil(elem, until) {
    var matched = [];

    while ((elem = elem.nextSibling) && elem.nodeType !== 9) {
      if (elem.nodeType === 1 && jQuery(elem).is(until)) {
        break;
      }
      matched.push(elem);
    }
    return $(matched);
  }

  $(function() {
    initWidget();
  });
})(jQuery);

(function($, window) {
  'use strict';

  // Blogger API info
  var apiUrl = 'https://www.googleapis.com/blogger/v3';
  var apiKey = 'AIzaSyCFhbGnjW06dYwvRCU8h_zjdpS4PYYbEe8';

  // Blog IDs can be found in the markup of the blog posts
  var blogs = {
    'android-developers': {
      id: '6755709643044947179',
      title: 'Android Developers Blog'
    }
  };
  var monthNames = ['January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'];

  var BlogReader = (function() {
    var reader;

    function BlogReader() {
      this.doneSetup = false;
    }

    /**
     * Initialize the blog reader and modal.
     */
    BlogReader.prototype.setup = function() {
      $('#jd-content').append(
          '<div id="blog-reader" data-modal="blog-reader" class="dac-modal dac-has-small-header">' +
            '<div class="dac-modal-container">' +
              '<div class="dac-modal-window">' +
                '<header class="dac-modal-header">' +
                  '<div class="dac-modal-header-actions">' +
                    '<a href="" class="dac-modal-header-open" target="_blank">' +
                      '<i class="dac-sprite dac-open-in-new"></i>' +
                    '</a>' +
                    '<button class="dac-modal-header-close" data-modal-toggle>' +
                    '</button>' +
                  '</div>' +
                  '<h2 class="norule dac-modal-header-title"></h2>' +
                '</header>' +
                '<div class="dac-modal-content dac-blog-reader">' +
                  '<time class="dac-blog-reader-date" pubDate></time>' +
                  '<h3 class="dac-blog-reader-title"></h3>' +
                  '<div class="dac-blog-reader-text clearfix"></div>' +
                '</div>' +
              '</div>' +
            '</div>' +
          '</div>');

      this.blogReader = $('#blog-reader').dacModal();

      this.doneSetup = true;
    };

    BlogReader.prototype.openModal_ = function(blog, post) {
      var published = new Date(post.published);
      var formattedDate = monthNames[published.getMonth()] + ' ' + published.getDate() + ' ' + published.getFullYear();
      this.blogReader.find('.dac-modal-header-open').attr('href', post.url);
      this.blogReader.find('.dac-modal-header-title').text(blog.title);
      this.blogReader.find('.dac-blog-reader-title').html(post.title);
      this.blogReader.find('.dac-blog-reader-date').html(formattedDate);
      this.blogReader.find('.dac-blog-reader-text').html(post.content);
      this.blogReader.trigger('modal-open');
    };

    /**
     * Show a blog post in a modal
     * @param  {string} blogName - The name of the Blogspot blog.
     * @param  {string} postPath - The path to the blog post.
     * @param  {bool} secondTry - Has it failed once?
     */
    BlogReader.prototype.showPost = function(blogName, postPath, secondTry) {
      var blog = blogs[blogName];
      var postUrl = 'https://' + blogName + '.blogspot.com' + postPath;

      var url = apiUrl + '/blogs/' + blog.id + '/posts/bypath?path=' + encodeURIComponent(postPath) + '&key=' + apiKey;
      $.ajax(url, {timeout: 650}).done(this.openModal_.bind(this, blog)).fail(function(error) {
        // Retry once if we get an error
        if (error.status === 500 && !secondTry) {
          this.showPost(blogName, postPath, true);
        } else {
          window.location.href = postUrl;
        }
      }.bind(this));
    };

    return {
      getReader: function() {
        if (!reader) {
          reader = new BlogReader();
        }
        return reader;
      }
    };
  })();

  var blogReader = BlogReader.getReader();

  function wrapLinkWithReader(e) {
    var el = $(e.currentTarget);
    if (el.hasClass('dac-modal-header-open')) {
      return;
    }

    // Only catch links on blogspot.com
    var matches = el.attr('href').match(/https?:\/\/([^\.]*).blogspot.com([^$]*)/);
    if (matches && matches.length === 3) {
      var blogName = matches[1];
      var postPath = matches[2];

      // Check if we have information about the blog
      if (!blogs[blogName]) {
        return;
      }

      // Setup the first time it's used
      if (!blogReader.doneSetup) {
        blogReader.setup();
      }

      e.preventDefault();
      blogReader.showPost(blogName, postPath);
    }
  }

  $(document).on('click.blog-reader', 'a.resource-card[href*="blogspot.com/"]',
      wrapLinkWithReader);
})(jQuery, window);

(function($) {
  $.fn.debounce = function(func, wait, immediate) {
    var timeout;

    return function() {
      var context = this;
      var args = arguments;

      var later = function() {
        timeout = null;
        if (!immediate) {
          func.apply(context, args);
        }
      };

      var callNow = immediate && !timeout;
      clearTimeout(timeout);
      timeout = setTimeout(later, wait);

      if (callNow) {
        func.apply(context, args);
      }
    };
  };
})(jQuery);

/* Calculate the vertical area remaining */
(function($) {
  $.fn.ellipsisfade = function() {
    // Only fetch line-height of first element to avoid recalculate style.
    // Will be NaN if no elements match, which is ok.
    var lineHeight = parseInt(this.css('line-height'), 10);

    this.each(function() {
      // get element text
      var $this = $(this);
      var remainingHeight = $this.parent().parent().height();
      $this.parent().siblings().each(function() {
        var elHeight;
        if ($(this).is(':visible')) {
          elHeight = $(this).outerHeight(true);
          remainingHeight = remainingHeight - elHeight;
        }
      });

      var adjustedRemainingHeight = ((remainingHeight) / lineHeight >> 0) * lineHeight;
      $this.parent().css({height: adjustedRemainingHeight});
      $this.css({height: 'auto'});
    });

    return this;
  };

  /* Pass the line height to ellipsisfade() to adjust the height of the
   text container to show the max number of lines possible, without
   showing lines that are cut off. This works with the css ellipsis
   classes to fade last text line and apply an ellipsis char. */
  function updateEllipsis(context) {
    if (!(context instanceof jQuery)) {
      context = $('html');
    }

    context.find('.card-info .text').ellipsisfade();
  }

  $(window).on('resize', $.fn.debounce(updateEllipsis, 500));
  $(updateEllipsis);
  $('html').on('dac:domchange', function(e) { updateEllipsis($(e.target)); });
})(jQuery);

/* Filter */
(function($) {
  'use strict';

  /**
   * A single filter item content.
   * @type {string} - Element template.
   * @private
   */
  var ITEM_STR_ = '<input type="checkbox" value="{{value}}" class="dac-form-checkbox" id="{{id}}">' +
      '<label for="{{id}}" class="dac-form-checkbox-button"></label>' +
      '<label for="{{id}}" class="dac-form-label">{{name}}</label>';

  /**
   * Template for a chip element.
   * @type {*|HTMLElement}
   * @private
   */
  var CHIP_BASE_ = $('<li class="dac-filter-chip">' +
    '<button class="dac-filter-chip-close">' +
      '<i class="dac-sprite dac-close-black dac-filter-chip-close-icon"></i>' +
    '</button>' +
  '</li>');

  /**
   * Component to handle narrowing down resources.
   * @param {HTMLElement} el - The DOM element.
   * @param {Object} options
   * @constructor
   */
  function Filter(el, options) {
    this.el = $(el);
    this.options = $.extend({}, Filter.DEFAULTS_, options);
    this.init();
  }

  Filter.DEFAULTS_ = {
    activeClass: 'dac-active',
    chipsDataAttr: 'filter-chips',
    nameDataAttr: 'filter-name',
    countDataAttr: 'filter-count',
    tabViewDataAttr: 'tab-view',
    valueDataAttr: 'filter-value'
  };

  /**
   * Draw resource cards.
   * @param {Array} resources
   * @private
   */
  Filter.prototype.draw_ = function(resources) {
    var that = this;

    if (resources.length === 0) {
      this.containerEl_.html('<p class="dac-filter-message">Nothing matches selected filters.</p>');
      return;
    }

    // Draw resources.
    that.containerEl_.resourceWidget(resources, that.data_.options);
  };

  /**
   * Initialize a Filter component.
   */
  Filter.prototype.init = function() {
    this.containerEl_ = $(this.options.filter);

    // Setup data settings
    this.data_ = {};
    this.data_.chips = {};
    this.data_.options = this.containerEl_.widgetOptions();
    this.data_.all = window.metadata.query(this.data_.options);

    // Initialize filter UI
    this.initUi();
  };

  /**
   * Generate a chip for a given filter item.
   * @param {Object} item - A single filter option (checkbox container).
   * @returns {HTMLElement} A new Chip element.
   */
  Filter.prototype.chipForItem = function(item) {
    var chip = CHIP_BASE_.clone();
    chip.prepend(this.data_.chips[item.data('filter-value')]);
    chip.data('item.dac-filter', item);
    item.data('chip.dac-filter', chip);
    this.addToItemValue(item, 1);
    return chip[0];
  };

  /**
   * Update count of checked filter items.
   * @param {Object} item - A single filter option (checkbox container).
   * @param {Number} value - Either -1 or 1.
   */
  Filter.prototype.addToItemValue = function(item, value) {
    var tab = item.parent().data(this.options.tabViewDataAttr);
    var countEl = this.countEl_.filter('[data-' + this.options.countDataAttr + '="' + tab + '"]');
    var count = value + parseInt(countEl.text(), 10);
    countEl.text(count);
    countEl.toggleClass('dac-disabled', count === 0);
  };

  /**
   * Set event listeners.
   * @private
   */
  Filter.prototype.setEventListeners_ = function() {
    this.chipsEl_.on('click.dac-filter', '.dac-filter-chip-close', this.closeChipHandler_.bind(this));
    this.tabViewEl_.on('change.dac-filter', ':checkbox', this.toggleCheckboxHandler_.bind(this));
  };

  /**
   * Check filter items that are active by default.
   */
  Filter.prototype.activateInitialFilters_ = function() {
    var id = (new Date()).getTime();
    var initiallyCheckedValues = this.data_.options.query.replace(/,\s*/g, '+').split('+');
    var chips = document.createDocumentFragment();
    var that = this;

    this.items_.each(function(i) {
      var item = $(this);
      var opts = item.data();
      that.data_.chips[opts.filterValue] = opts.filterName;

      var checkbox = $(ITEM_STR_.replace(/\{\{name\}\}/g, opts.filterName)
        .replace(/\{\{value\}\}/g, opts.filterValue)
        .replace(/\{\{id\}\}/g, 'filter-' + id + '-' + (i + 1)));

      if (initiallyCheckedValues.indexOf(opts.filterValue) > -1) {
        checkbox[0].checked = true;
        chips.appendChild(that.chipForItem(item));
      }

      item.append(checkbox);
    });

    this.chipsEl_.append(chips);
  };

  /**
   * Initialize the Filter view
   */
  Filter.prototype.initUi = function() {
    // Cache DOM elements
    this.chipsEl_ = this.el.find('[data-' + this.options.chipsDataAttr + ']');
    this.countEl_ = this.el.find('[data-' + this.options.countDataAttr + ']');
    this.tabViewEl_ = this.el.find('[data-' + this.options.tabViewDataAttr + ']');
    this.items_ = this.el.find('[data-' + this.options.nameDataAttr + ']');

    // Setup UI
    this.draw_(this.data_.all);
    this.activateInitialFilters_();
    this.setEventListeners_();
  };

  /**
   * @returns {[types|Array, tags|Array, category|Array]}
   */
  Filter.prototype.getActiveClauses = function() {
    var tags = [];
    var types = [];
    var categories = [];

    this.items_.find(':checked').each(function(i, checkbox) {
      // Currently, there is implicit business logic here that `tag` is AND'ed together
      // while `type` is OR'ed. So , and + do the same thing here. It would be great to
      // reuse the same query engine for filters, but it would need more powerful syntax.
      // Probably parenthesis, to support "tag:dog + tag:cat + (type:video, type:blog)"
      var expression = $(checkbox).val();
      var regex = /(\w+):(\w+)/g;
      var match;

      while (match = regex.exec(expression)) {
        switch (match[1]) {
          case 'category':
            categories.push(match[2]);
            break;
          case 'tag':
            tags.push(match[2]);
            break;
          case 'type':
            types.push(match[2]);
            break;
        }
      }
    });

    return [types, tags, categories];
  };

  /**
   * Actual filtering logic.
   * @returns {Array}
   */
  Filter.prototype.filteredResources = function() {
    var data = this.getActiveClauses();
    var types = data[0];
    var tags = data[1];
    var categories = data[2];
    var resources = [];
    var resource = {};
    var tag = '';
    var shouldAddResource = true;

    for (var resourceIndex = 0; resourceIndex < this.data_.all.length; resourceIndex++) {
      resource = this.data_.all[resourceIndex];
      shouldAddResource = types.indexOf(resource.type) > -1;

      if (categories && categories.length > 0) {
        shouldAddResource = shouldAddResource && categories.indexOf(resource.category) > -1;
      }

      for (var tagIndex = 0; shouldAddResource && tagIndex < tags.length; tagIndex++) {
        tag = tags[tagIndex];
        shouldAddResource = resource.tags.indexOf(tag) > -1;
      }

      if (shouldAddResource) {
        resources.push(resource);
      }
    }

    return resources;
  };

  /**
   * Close Chip Handler
   * @param {Event} event - Click event
   * @private
   */
  Filter.prototype.closeChipHandler_ = function(event) {
    var chip = $(event.currentTarget).parent();
    var checkbox = chip.data('item.dac-filter').find(':first-child')[0];
    checkbox.checked = false;
    this.changeStateForCheckbox(checkbox);
  };

  /**
   * Handle filter item state change.
   * @param {Event} event - Change event
   * @private
   */
  Filter.prototype.toggleCheckboxHandler_ = function(event) {
    this.changeStateForCheckbox(event.currentTarget);
  };

  /**
   * Redraw resource view based on new state.
   * @param checkbox
   */
  Filter.prototype.changeStateForCheckbox = function(checkbox) {
    var item = $(checkbox).parent();

    if (checkbox.checked) {
      this.chipsEl_.append(this.chipForItem(item));
      devsite.analytics.trackAnalyticsEvent('event',
          'Filters', 'Check', $(checkbox).val());
    } else {
      item.data('chip.dac-filter').remove();
      this.addToItemValue(item, -1);
      devsite.analytics.trackAnalyticsEvent('event',
          'Filters', 'Uncheck', $(checkbox).val());
    }

    this.draw_(this.filteredResources());
  };

  /**
   * jQuery plugin
   */
  $.fn.dacFilter = function() {
    return this.each(function() {
      var el = $(this);
      new Filter(el, el.data());
    });
  };

  /**
   * Data Attribute API
   */
  $(function() {
    $('[data-filter]').dacFilter();
  });
})(jQuery);

(function($) {
  'use strict';

  /**
   * Toggle Floating Label state.
   * @param {HTMLElement} el - The DOM element.
   * @param options
   * @constructor
   */
  function FloatingLabel(el, options) {
    this.el = $(el);
    this.options = $.extend({}, FloatingLabel.DEFAULTS_, options);
    this.group = this.el.closest('.dac-form-input-group');
    this.input = this.group.find('.dac-form-input');

    this.checkValue_ = this.checkValue_.bind(this);
    this.checkValue_();

    this.input.on('focus', function() {
      this.group.addClass('dac-focused');
    }.bind(this));
    this.input.on('blur', function() {
      this.group.removeClass('dac-focused');
      this.checkValue_();
    }.bind(this));
    this.input.on('keyup', this.checkValue_);
  }

  /**
   * The label is moved out of the textbox when it has a value.
   */
  FloatingLabel.prototype.checkValue_ = function() {
    if (this.input.val().length) {
      this.group.addClass('dac-has-value');
    } else {
      this.group.removeClass('dac-has-value');
    }
  };

  /**
   * jQuery plugin
   * @param  {object} options - Override default options.
   */
  $.fn.dacFloatingLabel = function(options) {
    return this.each(function() {
      new FloatingLabel(this, options);
    });
  };

  $(document).on('ready.aranja', function() {
    $('.dac-form-floatlabel').each(function() {
      $(this).dacFloatingLabel($(this).data());
    });
  });
})(jQuery);

(function($) {
  'use strict';

  /**
   * @param {HTMLElement} el - The DOM element.
   * @param {Object} options
   * @constructor
   */
  function Crumbs(selected, options) {
    this.options = $.extend({}, Crumbs.DEFAULTS_, options);
    this.el = $(this.options.container);

    // Do not build breadcrumbs for landing site.
    if (!selected || location.pathname === '/index.html' || location.pathname === '/') {
      return;
    }

    // Cache navigation resources
    this.selected = $(selected);
    this.selectedParent = this.selected.closest('.dac-nav-secondary').siblings('a');

    // Build the breadcrumb list.
    this.init();
  }

  Crumbs.DEFAULTS_ = {
    container: '.dac-header-crumbs',
    crumbItem: $('<li class="dac-header-crumbs-item">'),
    linkClass: 'dac-header-crumbs-link'
  };

  Crumbs.prototype.init = function() {
    Crumbs.buildCrumbForLink(this.selected.clone()).appendTo(this.el);

    if (this.selectedParent.length) {
      Crumbs.buildCrumbForLink(this.selectedParent.clone()).prependTo(this.el);
    }

    // Reveal the breadcrumbs
    this.el.addClass('dac-has-content');
  };

  /**
   * Build a HTML structure for a breadcrumb.
   * @param {string} link
   * @return {jQuery}
   */
  Crumbs.buildCrumbForLink = function(link) {
    link.find('br').replaceWith(' ');

    var crumbLink = $('<a>')
      .attr('class', Crumbs.DEFAULTS_.linkClass)
      .attr('href', link.attr('href'))
      .text(link.text());

    return Crumbs.DEFAULTS_.crumbItem.clone().append(crumbLink);
  };

  /**
   * jQuery plugin
   */
  $.fn.dacCrumbs = function(options) {
    return this.each(function() {
      new Crumbs(this, options);
    });
  };
})(jQuery);

(function($) {
  'use strict';

  /**
   * @param {HTMLElement} el - The DOM element.
   * @param {Object} options
   * @constructor
   */
  function SearchInput(el, options) {
    this.el = $(el);
    this.options = $.extend({}, SearchInput.DEFAULTS_, options);
    this.body = $('body');
    this.input = this.el.find('input');
    this.close = this.el.find(this.options.closeButton);
    this.clear = this.el.find(this.options.clearButton);
    this.icon = this.el.find('.' + this.options.iconClass);
    this.init();
  }

  SearchInput.DEFAULTS_ = {
    activeClass: 'dac-active',
    activeIconClass: 'dac-search',
    closeButton: '[data-search-close]',
    clearButton: '[data-search-clear]',
    hiddenClass: 'dac-hidden',
    iconClass: 'dac-header-search-icon',
    searchModeClass: 'dac-search-mode',
    transitionDuration: 250
  };

  SearchInput.prototype.init = function() {
    this.input.on('focus.dac-search', this.setActiveState.bind(this))
              .on('input.dac-search', this.checkInputValue.bind(this));
    this.close.on('click.dac-search', this.unsetActiveStateHandler_.bind(this));
    this.clear.on('click.dac-search', this.clearInput.bind(this));
  };

  SearchInput.prototype.setActiveState = function() {
    var that = this;

    this.clear.addClass(this.options.hiddenClass);
    this.body.addClass(this.options.searchModeClass);
    this.checkInputValue();

    // Set icon to black after background has faded to white.
    setTimeout(function() {
      that.icon.addClass(that.options.activeIconClass);
    }, this.options.transitionDuration);
  };

  SearchInput.prototype.unsetActiveStateHandler_ = function(event) {
    event.preventDefault();
    this.unsetActiveState();
  };

  SearchInput.prototype.unsetActiveState = function() {
    this.icon.removeClass(this.options.activeIconClass);
    this.clear.addClass(this.options.hiddenClass);
    this.body.removeClass(this.options.searchModeClass);
  };

  SearchInput.prototype.clearInput = function(event) {
    event.preventDefault();
    this.input.val('');
    this.clear.addClass(this.options.hiddenClass);
  };

  SearchInput.prototype.checkInputValue = function() {
    if (this.input.val().length) {
      this.clear.removeClass(this.options.hiddenClass);
    } else {
      this.clear.addClass(this.options.hiddenClass);
    }
  };

  /**
   * jQuery plugin
   * @param {object} options - Override default options.
   */
  $.fn.dacSearchInput = function() {
    return this.each(function() {
      var el = $(this);
      el.data('search-input.dac', new SearchInput(el, el.data()));
    });
  };

  /**
   * Data Attribute API
   */
  $(function() {
    $('[data-search]').dacSearchInput();
  });
})(jQuery);

/* global METADATA */
(function($) {
  function DacCarouselQuery(el) {
    el = $(el);

    var opts = el.data();
    opts.maxResults = parseInt(opts.maxResults || '100', 10);
    opts.query = opts.carouselQuery;
    var resources = window.metadata.query(opts);

    el.empty();
    $(resources).each(function() {
      var resource = $.extend({}, this, METADATA.carousel[this.url]);
      el.dacHero(resource);
    });

    // Pagination element.
    el.append('<div class="dac-hero-carousel-pagination"><div class="wrap" data-carousel-pagination>');

    el.dacCarousel();
  }

  // jQuery plugin
  $.fn.dacCarouselQuery = function() {
    return this.each(function() {
      var el = $(this);
      var data = el.data('dac.carouselQuery');

      if (!data) { el.data('dac.carouselQuery', (data = new DacCarouselQuery(el))); }
    });
  };

  // Data API
  $(function() {
    $('[data-carousel-query]').dacCarouselQuery();
  });
})(jQuery);

(function($) {
  /**
   * A CSS based carousel, inspired by SequenceJS.
   * @param {jQuery} el
   * @param {object} options
   * @constructor
   */
  function DacCarousel(el, options) {
    this.el = $(el);
    this.options = options = $.extend({}, DacCarousel.OPTIONS, this.el.data(), options || {});
    this.frames = this.el.find(options.frameSelector);
    this.count = this.frames.size();
    this.current = options.start;

    this.initPagination();
    this.initEvents();
    this.initFrame();
  }

  DacCarousel.OPTIONS = {
    auto:      true,
    autoTime:  10000,
    autoMinTime: 5000,
    btnPrev:   '[data-carousel-prev]',
    btnNext:   '[data-carousel-next]',
    frameSelector: 'article',
    loop:      true,
    start:     0,
    swipeThreshold: 160,
    pagination: '[data-carousel-pagination]'
  };

  DacCarousel.prototype.initPagination = function() {
    this.pagination = $([]);
    if (!this.options.pagination) { return; }

    var pagination = $('<ul class="dac-pagination">');
    var parent = this.el;
    if (typeof this.options.pagination === 'string') { parent = this.el.find(this.options.pagination); }

    if (this.count > 1) {
      for (var i = 0; i < this.count; i++) {
        var li = $('<li class="dac-pagination-item">').text(i);
        if (i === this.options.start) { li.addClass('active'); }
        li.click(this.go.bind(this, i));

        pagination.append(li);
      }
      this.pagination = pagination.children();
      parent.append(pagination);
    }
  };

  DacCarousel.prototype.initEvents = function() {
    var that = this;

    this.touch = {
      start: {x: 0, y: 0},
      end:   {x: 0, y: 0}
    };

    this.el.on('touchstart', this.touchstart_.bind(this));
    this.el.on('touchend', this.touchend_.bind(this));
    this.el.on('touchmove', this.touchmove_.bind(this));

    this.el.hover(function() {
      that.pauseRotateTimer();
    }, function() {
      that.startRotateTimer();
    });

    $(this.options.btnPrev).click(function(e) {
      e.preventDefault();
      that.prev();
    });

    $(this.options.btnNext).click(function(e) {
      e.preventDefault();
      that.next();
    });
  };

  DacCarousel.prototype.touchstart_ = function(event) {
    var t = event.originalEvent.touches[0];
    this.touch.start = {x: t.screenX, y: t.screenY};
  };

  DacCarousel.prototype.touchend_ = function() {
    var deltaX = this.touch.end.x - this.touch.start.x;
    var deltaY = Math.abs(this.touch.end.y - this.touch.start.y);
    var shouldSwipe = (deltaY < Math.abs(deltaX)) && (Math.abs(deltaX) >= this.options.swipeThreshold);

    if (shouldSwipe) {
      if (deltaX > 0) {
        this.prev();
      } else {
        this.next();
      }
    }
  };

  DacCarousel.prototype.touchmove_ = function(event) {
    var t = event.originalEvent.touches[0];
    this.touch.end = {x: t.screenX, y: t.screenY};
  };

  DacCarousel.prototype.initFrame = function() {
    this.frames.removeClass('active').eq(this.options.start).addClass('active');
  };

  DacCarousel.prototype.startRotateTimer = function() {
    if (!this.options.auto || this.rotateTimer) { return; }
    this.rotateTimer = setTimeout(this.next.bind(this), this.options.autoTime);
  };

  DacCarousel.prototype.pauseRotateTimer = function() {
    clearTimeout(this.rotateTimer);
    this.rotateTimer = null;
  };

  DacCarousel.prototype.prev = function() {
    this.go(this.current - 1);
  };

  DacCarousel.prototype.next = function() {
    this.go(this.current + 1);
  };

  DacCarousel.prototype.go = function(next) {
    // Figure out what the next slide is.
    while (this.count > 0 && next >= this.count) { next -= this.count; }
    while (next < 0) { next += this.count; }

    // Cancel if we're already on that slide.
    if (next === this.current) { return; }

    // Prepare next slide.
    this.frames.eq(next).removeClass('out');

    // Recalculate styles before starting slide transition.
    this.el.resolveStyles();
    // Update pagination
    this.pagination.removeClass('active').eq(next).addClass('active');

    // Transition out current frame
    this.frames.eq(this.current).toggleClass('active out');

    // Transition in a new frame
    this.frames.eq(next).toggleClass('active');

    this.current = next;
  };

  // Helper which resolves new styles for an element, so it can start transitioning
  // from the new values.
  $.fn.resolveStyles = function() {
    /*jshint expr:true*/
    this[0] && this[0].offsetTop;
    return this;
  };

  // jQuery plugin
  $.fn.dacCarousel = function() {
    this.each(function() {
      var $el = $(this);
      $el.data('dac-carousel', new DacCarousel(this));
    });
    return this;
  };

  // Data API
  $(function() {
    $('[data-carousel]').dacCarousel();
  });
})(jQuery);

/* global toRoot */

(function($) {
  // Ordering matters
  var TAG_MAP = [
    {from: 'developerstory', to: 'Android Developer Story'},
    {from: 'googleplay', to: 'Google Play'}
  ];

  function DacHero(el, resource, isSearch) {
    var slide = $('<article>');
    slide.addClass(isSearch ? 'dac-search-hero' : 'dac-expand dac-hero');
    var image = cleanUrl(resource.heroImage || resource.image);
    var fullBleed = image && !resource.heroColor;

    if (!isSearch) {
      // Configure background
      slide.css({
        backgroundImage: fullBleed ? 'url(' + image + ')' : '',
        backgroundColor: resource.heroColor || ''
      });

      // Should copy be inverted
      slide.toggleClass('dac-invert', resource.heroInvert || fullBleed);
      slide.toggleClass('dac-darken', fullBleed);

      // Should be clickable
      slide.append($('<a class="dac-hero-carousel-action">').attr('href', cleanUrl(resource.url)));
    }

    var cols = $('<div class="cols dac-hero-content">');

    // inline image column
    var rightCol = $('<div class="col-1of2 col-push-1of2 dac-hero-figure">')
      .appendTo(cols);

    if ((!fullBleed || isSearch) && image) {
      rightCol.append($('<img>').attr('src', image));
    }

    // info column
    $('<div class="col-1of2 col-pull-1of2">')
      .append($('<div class="dac-hero-tag">').text(formatTag(resource)))
      .append($('<h1 class="dac-hero-title">').text(formatTitle(resource)))
      .append($('<p class="dac-hero-description">').text(resource.summary))
      .append($('<a class="dac-hero-cta">')
        .text(formatCTA(resource))
        .attr('href', cleanUrl(resource.url))
        .prepend($('<span class="dac-sprite dac-auto-chevron">'))
      )
      .appendTo(cols);

    slide.append(cols.wrap('<div class="wrap">').parent());
    el.append(slide);
  }

  function cleanUrl(url) {
    if (url && url.indexOf('//') === -1) {
      url = toRoot + url;
    }
    return url;
  }

  function formatTag(resource) {
    // Hmm, need a better more scalable solution for this.
    for (var i = 0, mapping; mapping = TAG_MAP[i]; i++) {
      if (resource.tags.indexOf(mapping.from) > -1) {
        return mapping.to;
      }
    }
    return resource.type;
  }

  function formatTitle(resource) {
    return resource.title.replace(/android developer story: /i, '');
  }

  function formatCTA(resource) {
    return resource.type === 'youtube' ? 'Watch the video' : 'Learn more';
  }

  // jQuery plugin
  $.fn.dacHero = function(resource, isSearch) {
    return this.each(function() {
      var el = $(this);
      return new DacHero(el, resource, isSearch);
    });
  };
})(jQuery);

(function($) {
  'use strict';

  function highlightString(label, query) {
    query = query || '';
    //query = query.replace('<wbr>', '').replace('.', '\\.');
    var queryRE = new RegExp('(' + query + ')', 'ig');
    return label.replace(queryRE, '<em>$1</em>');
  }

  $.fn.highlightMatches = function(query) {
    return this.each(function() {
      var el = $(this);
      var label = el.html();
      var highlighted = highlightString(label, query);
      el.html(highlighted);
      el.addClass('highlighted');
    });
  };
})(jQuery);

/**
 * History tracking.
 * Track visited urls in localStorage.
 */
(function($) {
  var PAGES_TO_STORE_ = 100;
  var MIN_NUMBER_OF_PAGES_TO_DISPLAY_ = 6;
  var CONTAINER_SELECTOR_ = '.dac-search-results-history-wrap';

  /**
   * Generate resource cards for visited pages.
   * @param {HTMLElement} el
   * @constructor
   */
  function HistoryQuery(el) {
    this.el = $(el);

    // Only show history component if enough pages have been visited.
    if (getVisitedPages().length < MIN_NUMBER_OF_PAGES_TO_DISPLAY_) {
      this.el.closest(CONTAINER_SELECTOR_).addClass('dac-hidden');
      return;
    }

    // Rename query
    this.el.data('query', this.el.data('history-query'));

    // jQuery method to populate cards.
    this.el.resourceWidget();
  }

  /**
   * Fetch from localStorage an array of visted pages
   * @returns {Array}
   */
  function getVisitedPages() {
    var visited = localStorage.getItem('visited-pages');
    return visited ? JSON.parse(visited) : [];
  }

  /**
   * Return a page corresponding to cuurent pathname. If none exists, create one.
   * @param {Array} pages
   * @param {String} path
   * @returns {Object} Page
   */
  function getPageForPath(pages, path) {
    var page;

    // Backwards lookup for current page, last pages most likely to be visited again.
    for (var i = pages.length - 1; i >= 0; i--) {
      if (pages[i].path === path) {
        page = pages[i];

        // Remove page object from pages list to ensure correct ordering.
        pages.splice(i, 1);

        return page;
      }
    }

    // If storage limit is exceeded, remove last visited path.
    if (pages.length >= PAGES_TO_STORE_) {
      pages.shift();
    }

    return {path: path};
  }

  /**
   * Add current page to back of visited array, increase hit count by 1.
   */
  function addCurrectPage() {
    var path = location.pathname;

    // Do not track frontpage visits.
    if (path === '/' || path === '/index.html') {return;}

    var pages = getVisitedPages();
    var page = getPageForPath(pages, path);

    // New page visits have no hit count.
    page.hit = ~~page.hit + 1;

    // Most recently visted pages are located at the end of the visited array.
    pages.push(page);

    localStorage.setItem('visited-pages', JSON.stringify(pages));
  }

  /**
   * Hit count compare function.
   * @param {Object} a - page
   * @param {Object} b - page
   * @returns {number}
   */
  function byHit(a, b) {
    if (a.hit > b.hit) {
      return -1;
    } else if (a.hit < b.hit) {
      return 1;
    }

    return 0;
  }

  /**
   * Return a list of visited urls in a given order.
   * @param {String} order - (recent|most-visited)
   * @returns {Array}
   */
  $.dacGetVisitedUrls = function(order) {
    var pages = getVisitedPages();

    if (order === 'recent') {
      pages.reverse();
    } else {
      pages.sort(byHit);
    }

    return pages.map(function(page) {
      return page.path.replace(/^\//, '');
    });
  };

  // jQuery plugin
  $.fn.dacHistoryQuery = function() {
    return this.each(function() {
      var el = $(this);
      var data = el.data('dac.recentlyVisited');

      if (!data) {
        el.data('dac.recentlyVisited', (data = new HistoryQuery(el)));
      }
    });
  };

  $(function() {
    $('[data-history-query]').dacHistoryQuery();
    // Do not block page rendering.
    setTimeout(addCurrectPage, 0);
  });
})(jQuery);

/* ############################################ */
/* ##########     LOCALIZATION     ############ */
/* ############################################ */
/**
 * Global helpers.
 */
function getBaseUri(uri) {
  var intlUrl = (uri.substring(0, 6) === '/intl/');
  if (intlUrl) {
    var base = uri.substring(uri.indexOf('intl/') + 5, uri.length);
    base = base.substring(base.indexOf('/') + 1, base.length);
    return '/' + base;
  } else {
    return uri;
  }
}

function changeLangPref(targetLang, submit) {
  window.writeCookie('pref_lang', targetLang, null);
  $('#language').find('option[value="' + targetLang + '"]').attr('selected', true);
  if (submit) {
    $('#setlang').submit();
  }
}
// Redundant usage to appease jshint.
window.changeLangPref = changeLangPref;

(function() {
  /**
   * Whitelisted locales. Should match choices in language dropdown. Repeated here
   * as a lot of i18n logic happens before page load and dropdown is ready.
   */
  var LANGUAGES = [
    'en',
    'es',
    'in',
    'ja',
    'ko',
    'pt-br',
    'ru',
    'vi',
    'zh-cn',
    'zh-tw'
  ];

  /**
   * Master list of translated strings for template files.
   */
  var PHRASES = {
    'newsletter': {
      'title': 'Get the latest Android developer news and tips that will help you find success on Google Play.',
      'requiredHint': '* Required Fields',
      'name': 'Full name',
      'email': 'Email address',
      'company': 'Company / developer name',
      'appUrl': 'One of your Play Store app URLs',
      'business': {
        'label': 'Which best describes your business:',
        'apps': 'Apps',
        'games': 'Games',
        'both': 'Apps & Games'
      },
      'confirmMailingList': 'Add me to the mailing list for the monthly newsletter and occasional emails about ' +
                            'development and Google Play opportunities.',
      'privacyPolicy': 'I acknowledge that the information provided in this form will be subject to Google\'s ' +
                       '<a href="https://www.google.com/policies/privacy/" target="_blank">privacy policy</a>.',
      'languageVal': 'English',
      'successTitle': 'Hooray!',
      'successDetails': 'You have successfully signed up for the latest Android developer news and tips.',
      'languageValTarget': {
        'en': 'English',
        'ar': 'Arabic (العربيّة)',
        'in': 'Indonesian (Bahasa)',
        'fr': 'French (français)',
        'de': 'German (Deutsch)',
        'ja': 'Japanese (日本語)',
        'ko': 'Korean (한국어)',
        'ru': 'Russian (Русский)',
        'es': 'Spanish (español)',
        'th': 'Thai (ภาษาไทย)',
        'tr': 'Turkish (Türkçe)',
        'vi': 'Vietnamese (tiếng Việt)',
        'pt-br': 'Brazilian Portuguese (Português Brasileiro)',
        'zh-cn': 'Simplified Chinese (简体中文)',
        'zh-tw': 'Traditional Chinese (繁體中文)',
      },
      'resetLangTitle': "Browse this site in %{targetLang}?",
      'resetLangTextIntro': 'You requested a page in %{targetLang}, but your language preference for this site is %{lang}.',
      'resetLangTextCta': 'Would you like to change your language preference and browse this site in %{targetLang}? ' +
                          'If you want to change your language preference later, use the language menu at the bottom of each page.',
      'resetLangButtonYes': 'Change Language',
      'resetLangButtonNo': 'Not Now'
    }
  };

  /**
   * Current locale.
   */
  var locale = (function() {
    var lang = window.readCookie('pref_lang');
    if (lang === 0 || LANGUAGES.indexOf(lang) === -1) {
      lang = 'en';
    }
    return lang;
  })();
  var localeTarget = (function() {
    var lang = getQueryVariable('hl');
    if (lang === false || LANGUAGES.indexOf(lang) === -1) {
      lang = locale;
    }
    return lang;
  })();

  /**
   * Global function shims for backwards compatibility
   */
  window.changeNavLang = function() {
    // Already done.
  };

  window.loadLangPref = function() {
    // Languages pref already loaded.
  };

  window.getLangPref = function() {
    return locale;
  };

  window.getLangTarget = function() {
    return localeTarget;
  };

  // Expose polyglot instance for advanced localization.
  var polyglot = window.polyglot = new window.Polyglot({
    locale: locale,
    phrases: PHRASES
  });

  // When DOM is ready.
  $(function() {
    // Mark current locale in language picker.
    $('#language').find('option[value="' + locale + '"]').attr('selected', true);

    $('html').dacTranslate().on('dac:domchange', function(e) {
      $(e.target).dacTranslate();
    });
  });

  $.fn.dacTranslate = function() {
    // Translate strings in template markup:

    // OLD
    // Having all translations in HTML does not scale well and bloats every page.
    // Need to migrate this to data-l JS translations below.
    if (locale !== 'en') {
      var $links = this.find('a[' + locale + '-lang]');
      $links.each(function() { // for each link with a translation
        var $link = $(this);
        // put the desired language from the attribute as the text
        $link.text($link.attr(locale + '-lang'));
      });
    }

    // NEW
    // A simple declarative api for JS translations. Feel free to extend as appropriate.

    // Miscellaneous string compilations
    // Build full strings from localized substrings:
    var myLocaleTarget = window.getLangTarget();
    var myTargetLang = window.polyglot.t("newsletter.languageValTarget." + myLocaleTarget);
    var myLang = window.polyglot.t("newsletter.languageVal");
    var myTargetLangTitleString = window.polyglot.t("newsletter.resetLangTitle", {targetLang: myTargetLang});
    var myResetLangTextIntro = window.polyglot.t("newsletter.resetLangTextIntro", {targetLang: myTargetLang, lang: myLang});
    var myResetLangTextCta = window.polyglot.t("newsletter.resetLangTextCta", {targetLang: myTargetLang});
    //var myResetLangButtonYes = window.polyglot.t("newsletter.resetLangButtonYes", {targetLang: myTargetLang});

    // Inject strings as text values in dialog components:
    $("#langform .dac-modal-header-title").text(myTargetLangTitleString);
    $("#langform #resetLangText").text(myResetLangTextIntro);
    $("#langform #resetLangCta").text(myResetLangTextCta);
    //$("#resetLangButtonYes").attr("data-t", window.polyglot.t(myResetLangButtonYes));

    // Text: <div data-t="nav.home"></div>
    // HTML: <div data-t="privacy" data-t-html></html>
    this.find('[data-t]').each(function() {
      var el = $(this);
      var data = el.data();
      if (data.t) {
        el[data.tHtml === '' ? 'html' : 'text'](polyglot.t(data.t));
      }
    });

    return this;
  };
})();
/* ##########     END LOCALIZATION     ############ */

// Translations. These should eventually be moved into language-specific files and loaded on demand.
// jshint nonbsp:false
switch (window.getLangPref()) {
  case 'ar':
    window.polyglot.extend({
      'newsletter': {
        'title': 'Google Play. يمكنك الحصول على آخر الأخبار والنصائح من مطوّري تطبيقات Android، مما يساعدك ' +
          'على تحقيق النجاح على',
        'requiredHint': '* حقول مطلوبة',
        'name': '. الاسم بالكامل ',
        'email': '. عنوان البريد الإلكتروني ',
        'company': '. اسم الشركة / اسم مطوّر البرامج',
        'appUrl': '. أحد عناوين URL لتطبيقاتك في متجر Play',
        'business': {
          'label': '. ما العنصر الذي يوضح طبيعة نشاطك التجاري بدقة؟ ',
          'apps': 'التطبيقات',
          'games': 'الألعاب',
          'both': 'التطبيقات والألعاب'
        },
        'confirmMailingList': 'إضافتي إلى القائمة البريدية للنشرة الإخبارية الشهرية والرسائل الإلكترونية التي يتم' +
          ' إرسالها من حين لآخر بشأن التطوير وفرص Google Play.',
        'privacyPolicy': 'أقر بأن المعلومات المقدَّمة في هذا النموذج تخضع لسياسة خصوصية ' +
          '<a href="https://www.google.com/intl/ar/policies/privacy/" target="_blank">Google</a>.',
        'languageVal': 'Arabic (العربيّة)',
        'successTitle': 'رائع!',
        'successDetails': 'لقد اشتركت بنجاح للحصول على آخر الأخبار والنصائح من مطوّري برامج Android.'
      }
    });
    break;
  case 'zh-cn':
    window.polyglot.extend({
      'newsletter': {
        'title': '获取最新的 Android 开发者资讯和提示，助您在 Google Play 上取得成功。',
        'requiredHint': '* 必填字段',
        'name': '全名',
        'email': '电子邮件地址',
        'company': '公司/开发者名称',
        'appUrl': '您的某个 Play 商店应用网址',
        'business': {
          'label': '哪一项能够最准确地描述您的业务？',
          'apps': '应用',
          'games': '游戏',
          'both': '应用和游戏'
        },
        'confirmMailingList': '将我添加到邮寄名单，以便接收每月简报以及不定期发送的关于开发和 Google Play 商机的电子邮件。',
        'privacyPolicy': '我确认自己了解在此表单中提供的信息受 <a href="https://www.google.com/intl/zh-CN/' +
        'policies/privacy/" target="_blank">Google</a> 隐私权政策的约束。',
        'languageVal': 'Simplified Chinese (简体中文)',
        'successTitle': '太棒了！',
        'successDetails': '您已成功订阅最新的 Android 开发者资讯和提示。'
      }
    });
    break;
  case 'zh-tw':
    window.polyglot.extend({
      'newsletter': {
        'title': '獲得 Android 開發人員的最新消息和各項秘訣，讓您在 Google Play 上輕鬆邁向成功之路。',
        'requiredHint': '* 必要欄位',
        'name': '全名',
        'email': '電子郵件地址',
        'company': '公司/開發人員名稱',
        'appUrl': '您其中一個 Play 商店應用程式的網址',
        'business': {
          'label': '為您的商家選取最合適的產品類別。',
          'apps': '應用程式',
          'games': '遊戲',
          'both': '應用程式和遊戲'
        },
        'confirmMailingList': '我想加入 Google Play 的郵寄清單，以便接收每月電子報和 Google Play 不定期寄送的電子郵件，' +
          '瞭解關於開發和 Google Play 商機的資訊。',
        'privacyPolicy': '我瞭解，我在這張表單中提供的資訊將受到 <a href="' +
        'https://www.google.com/intl/zh-TW/policies/privacy/" target="_blank">Google</a> 隱私權政策.',
        'languageVal': 'Traditional Chinese (繁體中文)',
        'successTitle': '太棒了！',
        'successDetails': '您已經成功訂閱 Android 開發人員的最新消息和各項秘訣。'
      }
    });
    break;
  case 'fr':
    window.polyglot.extend({
      'newsletter': {
        'title': 'Recevez les dernières actualités destinées aux développeurs Android, ainsi que des conseils qui ' +
          'vous mèneront vers le succès sur Google Play.',
        'requiredHint': '* Champs obligatoires',
        'name': 'Nom complet',
        'email': 'Adresse e-mail',
        'company': 'Nom de la société ou du développeur',
        'appUrl': 'Une de vos URL Play Store',
        'business': {
          'label': 'Quelle option décrit le mieux votre activité ?',
          'apps': 'Applications',
          'games': 'Jeux',
          'both': 'Applications et jeux'
        },
        'confirmMailingList': 'Ajoutez-moi à la liste de diffusion de la newsletter mensuelle et tenez-moi informé ' +
          'par des e-mails occasionnels de l\'évolution et des opportunités de Google Play.',
        'privacyPolicy': 'Je comprends que les renseignements fournis dans ce formulaire seront soumis aux <a href="' +
        'https://www.google.com/intl/fr/policies/privacy/" target="_blank">règles de confidentialité</a> de Google.',
        'languageVal': 'French (français)',
        'successTitle': 'Super !',
        'successDetails': 'Vous êtes bien inscrit pour recevoir les actualités et les conseils destinés aux ' +
          'développeurs Android.'
      }
    });
    break;
  case 'de':
    window.polyglot.extend({
      'newsletter': {
        'title': 'Abonniere aktuelle Informationen und Tipps für Android-Entwickler und werde noch erfolgreicher ' +
          'bei Google Play.',
        'requiredHint': '* Pflichtfelder',
        'name': 'Vollständiger Name',
        'email': 'E-Mail-Adresse',
        'company': 'Unternehmens-/Entwicklername',
        'appUrl': 'Eine der URLs deiner Play Store App',
        'business': {
          'label': 'Welche der folgenden Kategorien beschreibt dein Unternehmen am besten?',
          'apps': 'Apps',
          'games': 'Spiele',
          'both': 'Apps und Spiele'
        },
        'confirmMailingList': 'Meine E-Mail-Adresse soll zur Mailingliste hinzugefügt werden, damit ich den ' +
          'monatlichen Newsletter sowie gelegentlich E-Mails zu Entwicklungen und Optionen bei Google Play erhalte.',
        'privacyPolicy': 'Ich bestätige, dass die in diesem Formular bereitgestellten Informationen gemäß der ' +
          '<a href="https://www.google.com/intl/de/policies/privacy/" target="_blank">Datenschutzerklärung</a> von ' +
          'Google verwendet werden dürfen.',
        'languageVal': 'German (Deutsch)',
        'successTitle': 'Super!',
        'successDetails': 'Du hast dich erfolgreich angemeldet und erhältst jetzt aktuelle Informationen und Tipps ' +
          'für Android-Entwickler.'
      }
    });
    break;
  case 'in':
    window.polyglot.extend({
      'newsletter': {
        'title': 'Receba as dicas e as notícias mais recentes para os desenvolvedores Android e seja bem-sucedido ' +
        'no Google Play.',
        'requiredHint': '* Bidang Wajib Diisi',
        'name': 'Nama lengkap',
        'email': 'Alamat email',
        'company': 'Nama pengembang / perusahaan',
        'appUrl': 'Salah satu URL aplikasi Play Store Anda',
        'business': {
          'label': 'Dari berikut ini, mana yang paling cocok dengan bisnis Anda?',
          'apps': 'Aplikasi',
          'games': 'Game',
          'both': 'Aplikasi dan Game'
        },
        'confirmMailingList': 'Tambahkan saya ke milis untuk mendapatkan buletin bulanan dan email sesekali mengenai ' +
          'perkembangan dan kesempatan yang ada di Google Play.',
        'privacyPolicy': 'Saya memahami bahwa informasi yang diberikan dalam formulir ini tunduk pada <a href="' +
        'https://www.google.com/intl/in/policies/privacy/" target="_blank">kebijakan privasi</a> Google.',
        'languageVal': 'Indonesian (Bahasa)',
        'successTitle': 'Hore!',
        'successDetails': 'Anda berhasil mendaftar untuk kiat dan berita pengembang Android terbaru.'
      }
    });
    break;
  case 'it':
    //window.polyglot.extend({
    //  'newsletter': {
    //    'title': 'Receba as dicas e as notícias mais recentes para os desenvolvedores Android e seja bem-sucedido ' +
    //    'no Google Play.',
    //    'requiredHint': '* Campos obrigatórios',
    //    'name': 'Nome completo',
    //    'email': 'Endereço de Email',
    //    'company': 'Nome da empresa / do desenvolvedor',
    //    'appUrl': 'URL de um dos seus apps da Play Store',
    //    'business': {
    //      'label': 'Qual das seguintes opções melhor descreve sua empresa?',
    //      'apps': 'Apps',
    //      'games': 'Jogos',
    //      'both': 'Apps e Jogos'
    //    },
    //    'confirmMailingList': 'Inscreva-me na lista de e-mails para que eu receba o boletim informativo mensal, ' +
    //    'bem como e-mails ocasionais sobre o desenvolvimento e as oportunidades do Google Play.',
    //    'privacyPolicy': 'Reconheço que as informações fornecidas neste formulário estão sujeitas à <a href="' +
    //    'https://www.google.com.br/policies/privacy/" target="_blank">Política de Privacidade</a> do Google.',
    //    'languageVal': 'Italian (italiano)',
    //    'successTitle': 'Uhu!',
    //    'successDetails': 'Você se inscreveu para receber as notícias e as dicas mais recentes para os ' +
    //    'desenvolvedores Android.',
    //  }
    //});
    break;
  case 'ja':
    window.polyglot.extend({
      'newsletter': {
        'title': 'Google Play での成功に役立つ Android デベロッパー向けの最新ニュースやおすすめの情報をお届けします。',
        'requiredHint': '* 必須',
        'name': '氏名',
        'email': 'メールアドレス',
        'company': '会社名 / デベロッパー名',
        'appUrl': 'Play ストア アプリの URL（いずれか 1 つ）',
        'business': {
          'label': 'お客様のビジネスに最もよく当てはまるものをお選びください。',
          'apps': 'アプリ',
          'games': 'ゲーム',
          'both': 'アプリとゲーム'
        },
        'confirmMailingList': '開発や Google Play の最新情報に関する毎月発行のニュースレターや不定期発行のメールを受け取る',
        'privacyPolicy': 'このフォームに入力した情報に <a href="https://www.google.com/intl/ja/policies/privacy/" ' +
          'target="_blank">Google</a> のプライバシー ポリシーが適用',
        'languageVal': 'Japanese (日本語)',
        'successTitle': '完了です！',
        'successDetails': 'Android デベロッパー向けの最新ニュースやおすすめの情報の配信登録が完了しました。'
      }
    });
    break;
  case 'ko':
    window.polyglot.extend({
      'newsletter': {
        'title': 'Google Play에서 성공을 거두는 데 도움이 되는 최신 Android 개발자 소식 및 도움말을 받아 보세요.',
        'requiredHint': '* 필수 입력란',
        'name': '이름',
        'email': '이메일 주소',
        'company': '회사/개발자 이름',
        'appUrl': 'Play 스토어 앱 URL 중 1개',
        'business': {
          'label': '다음 중 내 비즈니스를 가장 잘 설명하는 단어는 무엇인가요?',
          'apps': '앱',
          'games': '게임',
          'both': '앱 및 게임'
        },
        'confirmMailingList': '개발 및 Google Play 관련 소식에 관한 월별 뉴스레터 및 비정기 이메일을 받아보겠습니다.',
        'privacyPolicy': '이 양식에 제공한 정보는 <a href="https://www.google.com/intl/ko/policies/privacy/" ' +
          'target="_blank">Google의</a> 개인정보취급방침에 따라 사용됨을',
        'languageVal':'Korean (한국어)',
        'successTitle': '축하합니다!',
        'successDetails': '최신 Android 개발자 뉴스 및 도움말을 받아볼 수 있도록 가입을 완료했습니다.'
      }
    });
    break;
  case 'pt-br':
    window.polyglot.extend({
      'newsletter': {
        'title': 'Receba as dicas e as notícias mais recentes para os desenvolvedores Android e seja bem-sucedido ' +
        'no Google Play.',
        'requiredHint': '* Campos obrigatórios',
        'name': 'Nome completo',
        'email': 'Endereço de Email',
        'company': 'Nome da empresa / do desenvolvedor',
        'appUrl': 'URL de um dos seus apps da Play Store',
        'business': {
          'label': 'Qual das seguintes opções melhor descreve sua empresa?',
          'apps': 'Apps',
          'games': 'Jogos',
          'both': 'Apps e Jogos'
        },
        'confirmMailingList': 'Inscreva-me na lista de e-mails para que eu receba o boletim informativo mensal, ' +
        'bem como e-mails ocasionais sobre o desenvolvimento e as oportunidades do Google Play.',
        'privacyPolicy': 'Reconheço que as informações fornecidas neste formulário estão sujeitas à <a href="' +
        'https://www.google.com.br/policies/privacy/" target="_blank">Política de Privacidade</a> do Google.',
        'languageVal': 'Brazilian Portuguese (Português Brasileiro)',
        'successTitle': 'Uhu!',
        'successDetails': 'Você se inscreveu para receber as notícias e as dicas mais recentes para os ' +
        'desenvolvedores Android.'
      }
    });
    break;
  case 'ru':
    window.polyglot.extend({
      'newsletter': {
        'title': 'Хотите получать последние новости и советы для разработчиков Google Play? Заполните эту форму.',
        'requiredHint': '* Обязательные поля',
        'name': 'Полное имя',
        'email': 'Адрес электронной почты',
        'company': 'Название компании или имя разработчика',
        'appUrl': 'Ссылка на любое ваше приложение в Google Play',
        'business': {
          'label': 'Что вы создаете?',
          'apps': 'Приложения',
          'games': 'Игры',
          'both': 'Игры и приложения'
        },
        'confirmMailingList': 'Я хочу получать ежемесячную рассылку для разработчиков и другие полезные новости ' +
          'Google Play.',
        'privacyPolicy': 'Я предоставляю эти данные в соответствии с <a href="' +
          'https://www.google.com/intl/ru/policies/privacy/" target="_blank">Политикой конфиденциальности</a> Google.',
        'languageVal': 'Russian (Русский)',
        'successTitle': 'Поздравляем!',
        'successDetails': 'Теперь вы подписаны на последние новости и советы для разработчиков Android.'
      }
    });
    break;
  case 'es':
    window.polyglot.extend({
      'newsletter': {
        'title': 'Recibe las últimas noticias y sugerencias para programadores de Android y logra tener éxito en ' +
          'Google Play.',
        'requiredHint': '* Campos obligatorios',
        'name': 'Dirección de correo electrónico',
        'email': 'Endereço de Email',
        'company': 'Nombre de la empresa o del programador',
        'appUrl': 'URL de una de tus aplicaciones de Play Store',
        'business': {
          'label': '¿Qué describe mejor a tu empresa?',
          'apps': 'Aplicaciones',
          'games': 'Juegos',
          'both': 'Juegos y aplicaciones'
        },
        'confirmMailingList': 'Deseo unirme a la lista de distribución para recibir el boletín informativo mensual ' +
          'y correos electrónicos ocasionales sobre desarrollo y oportunidades de Google Play.',
        'privacyPolicy': 'Acepto que la información que proporcioné en este formulario cumple con la <a href="' +
        'https://www.google.com/intl/es/policies/privacy/" target="_blank">política de privacidad</a> de Google.',
        'languageVal': 'Spanish (español)',
        'successTitle': '¡Felicitaciones!',
        'successDetails': 'El registro para recibir las últimas noticias y sugerencias para programadores de Android ' +
          'se realizó correctamente.'
      }
    });
    break;
  case 'th':
    window.polyglot.extend({
      'newsletter': {
        'title': 'รับข่าวสารล่าสุดสำหรับนักพัฒนาซอฟต์แวร์ Android ตลอดจนเคล็ดลับที่จะช่วยให้คุณประสบความสำเร็จบน ' +
          'Google Play',
        'requiredHint': '* ช่องที่ต้องกรอก',
        'name': 'ชื่อและนามสกุล',
        'email': 'ที่อยู่อีเมล',
        'company': 'ชื่อบริษัท/นักพัฒนาซอฟต์แวร์',
        'appUrl': 'URL แอปใดแอปหนึ่งของคุณใน Play สโตร์',
        'business': {
          'label': 'ข้อใดตรงกับธุรกิจของคุณมากที่สุด',
          'apps': 'แอป',
          'games': 'เกม',
          'both': 'แอปและเกม'
        },
        'confirmMailingList': 'เพิ่มฉันลงในรายชื่ออีเมลเพื่อรับจดหมายข่าวรายเดือนและอีเมลเป็นครั้งคราวเกี่ยวกับก' +
          'ารพัฒนาซอฟต์แวร์และโอกาสใน Google Play',
        'privacyPolicy': 'ฉันรับทราบว่าข้อมูลที่ให้ไว้ในแบบฟอร์มนี้จะเป็นไปตามนโยบายส่วนบุคคลของ ' +
          '<a href="https://www.google.com/intl/th/policies/privacy/" target="_blank">Google</a>',
        'languageVal': 'Thai (ภาษาไทย)',
        'successTitle': 'ไชโย!',
        'successDetails': 'คุณลงชื่อสมัครรับข่าวสารและเคล็ดลับล่าสุดสำหรับนักพัฒนาซอฟต์แวร์ Android เสร็จเรียบร้อยแล้ว'
      }
    });
    break;
  case 'tr':
    window.polyglot.extend({
      'newsletter': {
        'title': 'Google Play\'de başarılı olmanıza yardımcı olacak en son Android geliştirici haberleri ve ipuçları.',
        'requiredHint': '* Zorunlu Alanlar',
        'name': 'Tam ad',
        'email': 'E-posta adresi',
        'company': 'Şirket / geliştirici adı',
        'appUrl': 'Play Store uygulama URL\'lerinizden biri',
        'business': {
          'label': 'İşletmenizi en iyi hangisi tanımlar?',
          'apps': 'Uygulamalar',
          'games': 'Oyunlar',
          'both': 'Uygulamalar ve Oyunlar'
        },
        'confirmMailingList': 'Beni, geliştirme ve Google Play fırsatlarıyla ilgili ara sıra gönderilen e-posta ' +
          'iletilerine ilişkin posta listesine ve aylık haber bültenine ekle.',
        'privacyPolicy': 'Bu formda sağlanan bilgilerin Google\'ın ' +
          '<a href="https://www.google.com/intl/tr/policies/privacy/" target="_blank">Gizlilik Politikası\'na</a> ' +
          'tabi olacağını kabul ediyorum.',
        'languageVal': 'Turkish (Türkçe)',
        'successTitle': 'Yaşasın!',
        'successDetails': 'En son Android geliştirici haberleri ve ipuçlarına başarıyla kaydoldunuz.'
      }
    });
    break;
  case 'vi':
    window.polyglot.extend({
      'newsletter': {
        'title': 'Nhận tin tức và mẹo mới nhất dành cho nhà phát triển Android sẽ giúp bạn tìm thấy thành công trên ' +
          'Google Play.',
        'requiredHint': '* Các trường bắt buộc',
        'name': 'Tên đầy đủ',
        'email': 'Địa chỉ email',
        'company': 'Tên công ty/nhà phát triển',
        'appUrl': 'Một trong số các URL ứng dụng trên cửa hàng Play của bạn',
        'business': {
          'label': 'Lựa chọn nào sau đây mô tả chính xác nhất doanh nghiệp của bạn?',
          'apps': 'Ứng dụng',
          'games': 'Trò chơi',
          'both': 'Ứng dụng và trò chơi'
        },
        'confirmMailingList': 'Thêm tôi vào danh sách gửi thư cho bản tin hàng tháng và email định kỳ về việc phát ' +
          'triển và cơ hội của Google Play.',
        'privacyPolicy': 'Tôi xác nhận rằng thông tin được cung cấp trong biểu mẫu này tuân thủ chính sách bảo mật ' +
          'của <a href="https://www.google.com/intl/vi/policies/privacy/" target="_blank">Google</a>.',
        'languageVal': 'Vietnamese (tiếng Việt)',
        'successTitle': 'Thật tuyệt!',
        'successDetails': 'Bạn đã đăng ký thành công nhận tin tức và mẹo mới nhất dành cho nhà phát triển của Android.'
      }
    });
    break;
}

(function($) {
  'use strict';

  function Modal(el, options) {
    this.el = $(el);
    this.options = $.extend({}, options);
    this.isOpen = false;

    this.el.on('click', function(event) {
      if (!$.contains(this.el.find('.dac-modal-window')[0], event.target)) {
        return this.el.trigger('modal-close');
      }
    }.bind(this));

    this.el.on('modal-open', this.open_.bind(this));
    this.el.on('modal-close', this.close_.bind(this));
    this.el.on('modal-toggle', this.toggle_.bind(this));
  }

  Modal.prototype.toggle_ = function() {
    this.el.trigger('modal-' + (this.isOpen ? 'close' : 'open'));
  };

  Modal.prototype.close_ = function() {
    // When closing the modal for Android Studio downloads, reload the page
    // because otherwise we might get stuck with post-download dialog state
    if ($("[data-modal='studio_tos'].dac-active").length) {
      location.reload();
    }
    this.el.removeClass('dac-active');
    $('body').removeClass('dac-modal-open');
    this.isOpen = false;
  };

  Modal.prototype.open_ = function() {
    this.el.addClass('dac-active');
    $('body').addClass('dac-modal-open');
    this.isOpen = true;
  };

  function onClickToggleModal(event) {
    event.preventDefault();
    var toggle = $(event.currentTarget);
    var options = toggle.data();
    var modal = options.modalToggle ? $('[data-modal="' + options.modalToggle + '"]') :
      toggle.closest('[data-modal]');
    modal.trigger('modal-toggle');
  }

  /**
   * jQuery plugin
   * @param  {object} options - Override default options.
   */
  $.fn.dacModal = function(options) {
    return this.each(function() {
      new Modal(this, options);
    });
  };

  $.fn.dacToggleModal = function(options) {
    return this.each(function() {
      new ToggleModal(this, options);
    });
  };

  /**
   * Data Attribute API
   */
  $(document).on('ready.aranja', function() {
    $('[data-modal]').each(function() {
      $(this).dacModal($(this).data());
    });

    $('html').on('click.modal', '[data-modal-toggle]', onClickToggleModal);

    // Check if url anchor is targetting a toggle to open the modal.
    if (location.hash) {
      var $elem = $(document.getElementById(location.hash.substr(1)));
      if ($elem.attr('data-modal-toggle')) {
        $elem.trigger('click');
      }
    }

    var isTargetLangValid = false;
    $(ANDROID_LANGUAGES).each(function(index, langCode) {
      if (langCode == window.getLangTarget()) {
        isTargetLangValid = true;
        return;
      }
    });
    if (window.getLangTarget() !== window.getLangPref() && isTargetLangValid) {
        $('#langform').trigger('modal-open');
        $("#langform button.yes").attr("onclick","window.changeLangPref('" + window.getLangTarget() + "', true);  return false;");
        $("#langform button.no").attr("onclick","window.changeLangPref('" + window.getLangPref() + "', true); return false;");
    }

    /* Check the current API level, but only if we're in the reference */
    if (location.pathname.indexOf('/reference') == 0) {
      // init available apis based on user pref
      changeApiLevel();
    }
  });
})(jQuery);

/* Fullscreen - Toggle fullscreen mode for reference pages */
(function($) {
  'use strict';

  /**
   * @param {HTMLElement} el - The DOM element.
   * @constructor
   */
  function Fullscreen(el) {
    this.el = $(el);
    this.html = $('html');
    this.icon = this.el.find('.dac-sprite');
    this.isFullscreen = window.readCookie(Fullscreen.COOKIE_) === 'true';
    this.activate_();
    this.el.on('click.dac-fullscreen', this.toggleHandler_.bind(this));
  }

  /**
   * Cookie name for storing the state
   * @type {string}
   * @private
   */
  Fullscreen.COOKIE_ = 'fullscreen';

  /**
   * Classes to modify the DOM
   * @type {{mode: string, fullscreen: string, fullscreenExit: string}}
   * @private
   */
  Fullscreen.CLASSES_ = {
    mode: 'dac-fullscreen-mode',
    fullscreen: 'dac-fullscreen',
    fullscreenExit: 'dac-fullscreen-exit'
  };

  /**
   * Event listener for toggling fullscreen mode
   * @param {MouseEvent} event
   * @private
   */
  Fullscreen.prototype.toggleHandler_ = function(event) {
    event.stopPropagation();
    this.toggle(!this.isFullscreen, true);
  };

  /**
   * Change the DOM based on current state.
   * @private
   */
  Fullscreen.prototype.activate_ = function() {
    this.icon.toggleClass(Fullscreen.CLASSES_.fullscreen, !this.isFullscreen);
    this.icon.toggleClass(Fullscreen.CLASSES_.fullscreenExit, this.isFullscreen);
    this.html.toggleClass(Fullscreen.CLASSES_.mode, this.isFullscreen);
  };

  /**
   * Toggle fullscreen mode and store the state in a cookie.
   */
  Fullscreen.prototype.toggle = function() {
    this.isFullscreen = !this.isFullscreen;
    window.writeCookie(Fullscreen.COOKIE_, this.isFullscreen, null);
    this.activate_();
  };

  /**
   * jQuery plugin
   */
  $.fn.dacFullscreen = function() {
    return this.each(function() {
      new Fullscreen($(this));
    });
  };
})(jQuery);

(function($) {
  'use strict';

  /**
   * @param {HTMLElement} selected - The link that is selected in the nav.
   * @constructor
   */
  function HeaderTabs(selected) {

    // Don't highlight any tabs on the index page
    if (location.pathname === '/index.html' || location.pathname === '/') {
      //return;
    }

    this.selected = $(selected);
    this.selectedParent = this.selected.closest('.dac-nav-secondary').siblings('a');
    this.links = $('.dac-header-tabs a');

    this.selectActiveTab();
  }

  HeaderTabs.prototype.selectActiveTab = function() {
    var section = null;

    if (this.selectedParent.length) {
      section = this.selectedParent.text();
    } else {
      section = this.selected.text();
    }

    if (section) {
      this.links.removeClass('selected');

      this.links.filter(function() {
        return $(this).text() === $.trim(section);
      }).addClass('selected');
    }
  };

  /**
   * jQuery plugin
   */
  $.fn.dacHeaderTabs = function() {
    return this.each(function() {
      new HeaderTabs(this);
    });
  };
})(jQuery);

(function($) {
  'use strict';
  var icon = $('<i/>').addClass('dac-sprite dac-nav-forward');
  var config = JSON.parse(window.localStorage.getItem('global-navigation') || '{}');
  var forwardLink = $('<span/>')
    .addClass('dac-nav-link-forward')
    .html(icon)
    .attr('tabindex', 0)
    .on('click keypress', function(e) {
      if (e.type == 'keypress' && e.which == 13 || e.type == 'click') {
        swap_(e);
      }
    });

  /**
   * @constructor
   */
  function Nav(navigation) {
    $('.dac-nav-list').dacCurrentPage().dacHeaderTabs().dacSidebarToggle($('body'));

    navigation.find('[data-reference-tree]').dacReferenceNav();

    setupViews_(navigation.children().eq(0).children());

    initCollapsedNavs(navigation.find('.dac-nav-sub-slider'));

    $('#dac-main-navigation').scrollIntoView('.selected')
  }

  function updateStore(icon) {
    var navClass = getCurrentLandingPage_(icon);
    var isExpanded = icon.hasClass('dac-expand-less-black');
    var expandedNavs = config.expanded || [];
    if (isExpanded) {
      expandedNavs.push(navClass);
    } else {
      expandedNavs = expandedNavs.filter(function(item) {
        return item !== navClass;
      });
    }
    config.expanded = expandedNavs;
    window.localStorage.setItem('global-navigation', JSON.stringify(config));
  }

  function toggleSubNav_(icon) {
    var isExpanded = icon.hasClass('dac-expand-less-black');
    icon.toggleClass('dac-expand-less-black', !isExpanded);
    icon.toggleClass('dac-expand-more-black', isExpanded);
    icon.data('sub-navigation.dac').slideToggle(200);

    updateStore(icon);
  }

  function handleSubNavToggle_(event) {
    event.preventDefault();
    var icon = $(event.target);
    toggleSubNav_(icon);
  }

  function getCurrentLandingPage_(icon) {
    return icon.closest('li')[0].className.replace('dac-nav-item ', '');
  }

  // Setup sub navigation collapse/expand
  function initCollapsedNavs(toggleIcons) {
    toggleIcons.each(setInitiallyActive_($('body')));
    toggleIcons.on('click keypress', function(e) {
      if (e.type == 'keypress' && e.which == 13 || e.type == 'click') {
        handleSubNavToggle_(e);
      }
    });
  }

  function setInitiallyActive_(body) {
    var expandedNavs = config.expanded || [];
    return function(i, icon) {
      icon = $(icon);
      var subNav = icon.next();

      if (!subNav.length) {
        return;
      }

      var landingPageClass = getCurrentLandingPage_(icon);
      var expanded = expandedNavs.indexOf(landingPageClass) >= 0;
      landingPageClass = landingPageClass === 'home' ? 'about' : landingPageClass;

      if (landingPageClass == 'about' && location.pathname == '/index.html') {
        expanded = true;
      }

      // TODO: Should read from localStorage
      var visible = body.hasClass(landingPageClass) || expanded;

      icon.data('sub-navigation.dac', subNav);
      icon.toggleClass('dac-expand-less-black', visible);
      icon.toggleClass('dac-expand-more-black', !visible);
      subNav.toggle(visible);
    };
  }

  function setupViews_(views) {
    if (views.length === 1) {
      // Active tier 1 nav.
      views.addClass('dac-active');
    } else {
      // Activate back button and tier 2 nav.
      views.slice(0, 2).addClass('dac-active');
      var selectedNav = views.eq(2).find('.selected').after(forwardLink);
      var langAttr = selectedNav.attr(window.getLangPref() + '-lang');
      //form the label from locale attr if possible, else set to selectedNav text value
      if ((typeof langAttr !== typeof undefined &&  langAttr !== false) && (langAttr !== '')) {
        $('.dac-nav-back-title').text(langAttr);
      } else {
        $('.dac-nav-back-title').text(selectedNav.text());
      }
    }

    // Navigation should animate.
    setTimeout(function() {
      views.removeClass('dac-no-anim');
    }, 10);
  }

  function swap_(event) {
    event.preventDefault();
    $(event.currentTarget).trigger('swap-content');
  }

  /**
   * jQuery plugin
   */
  $.fn.dacNav = function() {
    return this.each(function() {
      new Nav($(this));
    });
  };
})(jQuery);

/* global NAVTREE_DATA */
(function($) {
  /**
   * Build the reference navigation with namespace dropdowns.
   * @param {jQuery} el - The DOM element.
   */
  function buildReferenceNav(el) {
    var supportLibraryPath = '/reference/android/support/';
    var currPath = location.pathname;

    if (currPath.indexOf(supportLibraryPath) > -1) {
      updateSupportLibrariesNav(supportLibraryPath, currPath);
    }
    var namespaceList = el.find('[data-reference-namespaces]');
    var resources = $('[data-reference-resources]').detach();
    var selected = namespaceList.find('.selected');
    resources.appendTo(el);

    // Links should be toggleable.
    namespaceList.find('a').addClass('dac-reference-nav-toggle dac-closed');

    // Set the path for the navtree data to use.
    var navtree_filepath = getNavtreeFilePath(supportLibraryPath, currPath);

    // Load in all resources
    $.getScript(navtree_filepath, function(data, textStatus, xhr) {
      if (xhr.status === 200) {
        namespaceList.on(
            'click', 'a.dac-reference-nav-toggle', toggleResourcesHandler);
      }
    });

    // No setup required if no resources are present
    if (!resources.length) {
      return;
    }

    // The resources should be a part of selected namespace.
    var overview = addResourcesToView(resources, selected);

    // Currently viewing Overview
    if (location.href === overview.attr('href')) {
      overview.parent().addClass('selected');
    }

    // Open currently selected resource
    var listsToOpen = selected.children().eq(1);
    listsToOpen = listsToOpen.add(
        listsToOpen.find('.selected').parent()).show();

    // Mark dropdowns as open
    listsToOpen.prev().removeClass('dac-closed');

    // Scroll into view
    namespaceList.scrollIntoView(selected);
  }

  function getNavtreeFilePath(supportLibraryPath, currPath) {
    var navtree_filepath = '';
    var navtree_filename = 'navtree_data.js';
    if (currPath.indexOf(supportLibraryPath + 'test') > -1) {
      navtree_filepath = supportLibraryPath + 'test/' + navtree_filename;
    } else if (currPath.indexOf(supportLibraryPath + 'wearable') > -1) {
      navtree_filepath = supportLibraryPath + 'wearable/' + navtree_filename;
    } else {
      navtree_filepath = '/' + navtree_filename;
    }
    return navtree_filepath;
  }

  function updateSupportLibrariesNav(supportLibraryPath, currPath) {
    var navTitle = '';
    if (currPath.indexOf(supportLibraryPath + 'test') > -1) {
      navTitle = 'Test Support APIs';
    } else if (currPath.indexOf(supportLibraryPath + 'wearable') > -1) {
      navTitle = 'Wearable Support APIs';
    }
    $('#api-nav-title').text(navTitle);
    $('#api-level-toggle').hide();
  }

  /**
   * Handles the toggling of resources.
   * @param {Event} event
   */
  function toggleResourcesHandler(event) {
    event.preventDefault();
    if (event.type == 'click' || event.type == 'keypress' && event.which == 13) {
      var el = $(this);
      // If resources for given namespace is not present, fetch correct data.
      if (this.tagName === 'A' && !this.hasResources) {
        addResourcesToView(buildResourcesViewForData(getDataForNamespace(el.text())), el.parent());
      }

      el.toggleClass('dac-closed').next().slideToggle(200);
    }
  }

  /**
   * @param {String} namespace
   * @returns {Array} namespace data
   */
  function getDataForNamespace(namespace) {
    var namespaceData = NAVTREE_DATA.filter(function(data) {
      return data[0] === namespace;
    });

    return namespaceData.length ? namespaceData[0][2] : [];
  }

  /**
   * Build a list item for a resource
   * @param {Array} resource
   * @returns {String}
   */
  function buildResourceItem(resource) {
    return '<li class="api apilevel-' + resource[3] + '"><a href="/' + resource[1] + '">' + resource[0] + '</a></li>';
  }

  /**
   * Build resources list items.
   * @param {Array} resources
   * @returns {String}
   */
  function buildResourceList(resources) {
    return '<li><h2>' + resources[0] + '</h2><ul>' + resources[2].map(buildResourceItem).join('') + '</ul>';
  }

  /**
   * Build a resources view
   * @param {Array} data
   * @returns {jQuery} resources in an unordered list.
   */
  function buildResourcesViewForData(data) {
    return $('<ul>' + data.map(buildResourceList).join('') + '</ul>');
  }

  /**
   * Add resources to a containing view.
   * @param {jQuery} resources
   * @param {jQuery} view
   * @returns {jQuery} the overview link.
   */
  function addResourcesToView(resources, view) {
    var namespace = view.children().eq(0);
    var overview = $('<a href="' + namespace.attr('href') + '">Overview</a>');

    // Mark namespace with content;
    namespace[0].hasResources = true;

    // Add correct classes / event listeners to resources.
    resources.prepend($('<li>').html(overview))
      .find('a')
        .addClass('dac-reference-nav-resource')
      .end()
        .find('h2').attr('tabindex', 0)
        .addClass('dac-reference-nav-toggle dac-closed')
        .on('click keypress', toggleResourcesHandler)
      .end()
        .add(resources.find('ul'))
        .addClass('dac-reference-nav-resources')
      .end()
        .appendTo(view);

    return overview;
  }

  function setActiveReferencePackage(el) {
    var packageLinkEls = el.find('[data-reference-namespaces] a');
    var selected = null;
    var highestMatchCount = 0;
    packageLinkEls.each(function(index, linkEl) {
      var matchCount = 0;
      $(location.pathname.split('/')).each(function(index, subpath) {
        if (linkEl.href.indexOf('/' + subpath + '/') > -1) {
          matchCount++;
        }
      });
      if (matchCount > highestMatchCount) {
        selected = linkEl;
        highestMatchCount = matchCount;
      }
    });
    $(selected).parent().addClass('selected');
  }

  /**
   * jQuery plugin
   */
  $.fn.dacReferenceNav = function() {
    return this.each(function() {
      setActiveReferencePackage($(this));
      buildReferenceNav($(this));
    });
  };
})(jQuery);

/** Scroll a container to make a target element visible
 This is called when the page finished loading. */
$.fn.scrollIntoView = function(target) {
  if ('string' === typeof target) {
    target = this.find(target);
  }
  if (this.is(':visible')) {
    if (target.length == 0) {
      // If no selected item found, exit
      return;
    }

    // get the target element's offset from its container nav by measuring the element's offset
    // relative to the document then subtract the container nav's offset relative to the document
    var targetOffset = target.offset().top - this.offset().top;
    var containerHeight = this.height();
    if (targetOffset > containerHeight * .8) { // multiply nav height by .8 so we move up the item
      // if it's more than 80% down the nav
      // scroll the item up by an amount equal to 80% the container height
      this.scrollTop(targetOffset - (containerHeight * .8));
    }
  }
};

(function($) {
  $.fn.dacCurrentPage = function() {
    // Highlight the header tabs...
    // highlight Design tab
    var baseurl = getBaseUri(window.location.pathname);
    var urlSegments = baseurl.split('/');
    var navEl = this;
    var body = $('body');
    var subNavEl = navEl.find('.dac-nav-secondary');
    var parentNavEl;
    var selected;
    // In NDK docs, highlight appropriate sub-nav
    if (body.hasClass('dac-ndk')) {
      if (body.hasClass('guide')) {
        selected = navEl.find('> li.guides > a').addClass('selected');
      } else if (body.hasClass('reference')) {
        selected = navEl.find('> li.reference > a').addClass('selected');
      } else if (body.hasClass('samples')) {
        selected = navEl.find('> li.samples > a').addClass('selected');
      } else if (body.hasClass('downloads')) {
        selected = navEl.find('> li.downloads > a').addClass('selected');
      }
    } else if (body.hasClass('dac-studio')) {
      if (body.hasClass('download')) {
        selected = navEl.find('> li.download > a').addClass('selected');
      } else if (body.hasClass('features')) {
        selected = navEl.find('> li.features > a').addClass('selected');
      } else if (body.hasClass('guide')) {
        selected = navEl.find('> li.guide > a').addClass('selected');
      } else if (body.hasClass('preview')) {
        selected = navEl.find('> li.preview > a').addClass('selected');
      }
    } else if (body.hasClass('design')) {
      selected = navEl.find('> li.design > a').addClass('selected');
      // highlight Home nav
    } else if (body.hasClass('about') || location.pathname == '/index.html') {
      parentNavEl = navEl.find('> li.home > a');
      parentNavEl.addClass('has-subnav');
      // In Home docs, also highlight appropriate sub-nav
      if (urlSegments[1] === 'wear' || urlSegments[1] === 'tv' ||
        urlSegments[1] === 'auto') {
        selected = subNavEl.find('li.' + urlSegments[1] + ' > a').addClass('selected');
      } else if (urlSegments[1] === 'about') {
        selected = subNavEl.find('li.versions > a').addClass('selected');
      } else {
        selected = parentNavEl.removeClass('has-subnav').addClass('selected');
      }
      // highlight Develop nav
    } else if (body.hasClass('develop') || body.hasClass('google')) {
      parentNavEl = navEl.find('> li.develop > a');
      parentNavEl.addClass('has-subnav');
      // In Develop docs, also highlight appropriate sub-nav
      if (urlSegments[1] === 'training') {
        selected = subNavEl.find('li.training > a').addClass('selected');
      } else if (urlSegments[1] === 'guide') {
        selected = subNavEl.find('li.guide > a').addClass('selected');
      } else if (urlSegments[1] === 'reference') {
        // If the root is reference, but page is also part of Google Services, select Google
        if (body.hasClass('google')) {
          selected = subNavEl.find('li.google > a').addClass('selected');
        } else {
          selected = subNavEl.find('li.reference > a').addClass('selected');
        }
      } else if (body.hasClass('google')) {
        selected = subNavEl.find('li.google > a').addClass('selected');
      } else if (body.hasClass('samples')) {
        selected = subNavEl.find('li.samples > a').addClass('selected');
      } else {
        selected = parentNavEl.removeClass('has-subnav').addClass('selected');
      }
      // highlight Distribute nav
    } else if (body.hasClass('distribute')) {
      parentNavEl = navEl.find('> li.distribute > a');
      parentNavEl.addClass('has-subnav');
      // In Distribute docs, also highlight appropriate sub-nav
      if (urlSegments[2] === 'users') {
        selected = subNavEl.find('li.users > a').addClass('selected');
      } else if (urlSegments[2] === 'engage') {
        selected = subNavEl.find('li.engage > a').addClass('selected');
      } else if (urlSegments[2] === 'monetize') {
        selected = subNavEl.find('li.monetize > a').addClass('selected');
      } else if (urlSegments[2] === 'analyze') {
        selected = subNavEl.find('li.analyze > a').addClass('selected');
      } else if (urlSegments[2] === 'tools') {
        selected = subNavEl.find('li.disttools > a').addClass('selected');
      } else if (urlSegments[2] === 'stories') {
        selected = subNavEl.find('li.stories > a').addClass('selected');
      } else if (urlSegments[2] === 'essentials') {
        selected = subNavEl.find('li.essentials > a').addClass('selected');
      } else if (urlSegments[2] === 'googleplay') {
        selected = subNavEl.find('li.googleplay > a').addClass('selected');
      } else {
        selected = parentNavEl.removeClass('has-subnav').addClass('selected');
      }
    } else if (body.hasClass('preview')) {
      selected = navEl.find('> li.preview > a').addClass('selected');
    }
    return $(selected);
  };
})(jQuery);

(function($) {
  'use strict';

  /**
   * Toggle the visabilty of the mobile navigation.
   * @param {HTMLElement} el - The DOM element.
   * @param {Object} options
   * @constructor
   */
  function ToggleNav(el, options) {
    this.el = $(el);
    this.options = $.extend({}, ToggleNav.DEFAULTS_, options);
    this.body = $(document.body);
    this.navigation_ = this.body.find(this.options.navigation);
    this.el.on('click', this.clickHandler_.bind(this));
  }

  ToggleNav.BREAKPOINT_ = 980;

  /**
   * Open on correct sizes
   */
  function toggleSidebarVisibility(body) {
    var wasClosed = ('' + localStorage.getItem('navigation-open')) === 'false';
    // Override the local storage setting for navigation-open for child sites
    // with no-subnav class.
    if (document.body.classList.contains('no-subnav')) {
      wasClosed = false;
    }

    if (wasClosed) {
      body.removeClass(ToggleNav.DEFAULTS_.activeClass);
    } else if (window.innerWidth >= ToggleNav.BREAKPOINT_) {
      body.addClass(ToggleNav.DEFAULTS_.activeClass);
    } else {
      body.removeClass(ToggleNav.DEFAULTS_.activeClass);
    }
  }

  /**
   * ToggleNav Default Settings
   * @type {{body: boolean, dimmer: string, navigation: string, activeClass: string}}
   * @private
   */
  ToggleNav.DEFAULTS_ = {
    body: true,
    dimmer: '.dac-nav-dimmer',
    animatingClass: 'dac-nav-animating',
    navigation: '[data-dac-nav]',
    activeClass: 'dac-nav-open'
  };

  /**
   * The actual toggle logic.
   * @param {Event} event
   * @private
   */
  ToggleNav.prototype.clickHandler_ = function(event) {
    event.preventDefault();
    var animatingClass = this.options.animatingClass;
    var body = this.body;

    body.addClass(animatingClass);
    body.toggleClass(this.options.activeClass);

    setTimeout(function() {
      body.removeClass(animatingClass);
    }, this.navigation_.transitionDuration());

    if (window.innerWidth >= ToggleNav.BREAKPOINT_) {
      localStorage.setItem('navigation-open', body.hasClass(this.options.activeClass));
    }
  };

  /**
   * jQuery plugin
   * @param  {object} options - Override default options.
   */
  $.fn.dacToggleMobileNav = function() {
    return this.each(function() {
      var el = $(this);
      new ToggleNav(el, el.data());
    });
  };

  $.fn.dacSidebarToggle = function(body) {
    toggleSidebarVisibility(body);
    $(window).on('resize', toggleSidebarVisibility.bind(null, body));
  };

  /**
   * Data Attribute API
   */
  $(function() {
    $('[data-dac-toggle-nav]').dacToggleMobileNav();
  });
})(jQuery);

(function($) {
  'use strict';

  /**
   * Submit the newsletter form to a Google Form.
   * @param {HTMLElement} el - The Form DOM element.
   * @constructor
   */
  function NewsletterForm(el) {
    this.el = $(el);
    this.form = this.el.find('form');
    $('<iframe/>').hide()
      .attr('name', 'dac-newsletter-iframe')
      .attr('src', '')
      .insertBefore(this.form);
    this.el.find('[data-newsletter-language]').val(window.polyglot.t('newsletter.languageVal'));
    this.form.on('submit', this.submitHandler_.bind(this));
  }

  /**
   * Milliseconds until modal has vanished after modal-close is triggered.
   * @type {number}
   * @private
   */
  NewsletterForm.CLOSE_DELAY_ = 300;

  /**
   * Switch view to display form after close.
   * @private
   */
  NewsletterForm.prototype.closeHandler_ = function() {
    setTimeout(function() {
      this.el.trigger('swap-reset');
    }.bind(this), NewsletterForm.CLOSE_DELAY_);
  };

  /**
   * Reset the modal to initial state.
   * @private
   */
  NewsletterForm.prototype.reset_ = function() {
    this.form.trigger('reset');
    this.el.one('modal-close', this.closeHandler_.bind(this));
  };

  /**
   * Display a success view on submit.
   * @private
   */
  NewsletterForm.prototype.submitHandler_ = function() {
    this.el.one('swap-complete', this.reset_.bind(this));
    this.el.trigger('swap-content');
  };

  /**
   * jQuery plugin
   * @param  {object} options - Override default options.
   */
  $.fn.dacNewsletterForm = function(options) {
    return this.each(function() {
      new NewsletterForm(this, options);
    });
  };

  /**
   * Data Attribute API
   */
  $(document).on('ready.aranja', function() {
    $('[data-newsletter]').each(function() {
      $(this).dacNewsletterForm();
    });
  });
})(jQuery);

/* globals METADATA, YOUTUBE_RESOURCES, BLOGGER_RESOURCES */
window.metadata = {};

/**
 * Prepare metadata and indices for querying.
 */
window.metadata.prepare = (function() {
  // Helper functions.
  function mergeArrays() {
    return Array.prototype.concat.apply([], arguments);
  }

  /**
   * Creates lookup maps for a resource index.
   * I.e. where MAP['some tag'][resource.id] === true when that resource has 'some tag'.
   * @param resourceDict
   * @returns {{}}
   */
  function buildResourceLookupMap(resourceDict) {
    var map = {};
    for (var key in resourceDict) {
      var dictForKey = {};
      var srcArr = resourceDict[key];
      for (var i = 0; i < srcArr.length; i++) {
        dictForKey[srcArr[i].index] = true;
      }
      map[key] = dictForKey;
    }
    return map;
  }

  /**
   * Merges metadata maps for english and the current language into the global store.
   */
  function mergeMetadataMap(name, locale) {
    if (locale && locale !== 'en' && METADATA[locale]) {
      METADATA[name] = $.extend(METADATA.en[name], METADATA[locale][name]);
    } else {
      METADATA[name] = METADATA.en[name];
    }
  }

  /**
   * Index all resources by type, url, tag and category.
   * @param resources
   */
  function createIndices(resources) {
    // URL, type, tag and category lookups
    var byType = METADATA.byType = {};
    var byUrl = METADATA.byUrl = {};
    var byTag = METADATA.byTag = {};
    var byCategory = METADATA.byCategory = {};

    for (var i = 0; i < resources.length; i++) {
      var res = resources[i];

      // Store index.
      res.index = i;

      // Index by type.
      var type = res.type;
      if (type) {
        byType[type] = byType[type] || [];
        byType[type].push(res);
      }

      // Index by tag.
      var tags = res.tags || [];
      for (var j = 0; j < tags.length; j++) {
        var tag = tags[j];
        if (tag) {
          byTag[tag] = byTag[tag] || [];
          byTag[tag].push(res);
        }
      }

      // Index by category.
      var category = res.category;
      if (category) {
        byCategory[category] = byCategory[category] || [];
        byCategory[category].push(res);
      }

      // Index by url.
      var url = res.url;
      if (url) {
        res.baseUrl = url.replace(/^intl\/\w+[\/]/, '');
        byUrl[res.baseUrl] = res;
      }
    }
    METADATA.hasType = buildResourceLookupMap(byType);
    METADATA.hasTag = buildResourceLookupMap(byTag);
    METADATA.hasCategory = buildResourceLookupMap(byCategory);
  }

  return function() {
    // Only once.
    if (METADATA.all) { return; }

    // Get current language.
    var locale = getLangPref();
    // Merge english resources.
    if (useDevsiteMetadata) {
      var all_keys = Object.keys(METADATA['en']);
      METADATA.all = []

      $(all_keys).each(function(index, category) {
        if (RESERVED_METADATA_CATEGORY_NAMES.indexOf(category) == -1) {
          METADATA.all = mergeArrays(
            METADATA.all,
            METADATA.en[category]
          );
        }
      });

      METADATA.all = mergeArrays(
        METADATA.all,
        YOUTUBE_RESOURCES,
        BLOGGER_RESOURCES,
        METADATA.en.extras
      );
    } else {
      METADATA.all = mergeArrays(
        METADATA.en.about,
        METADATA.en.design,
        METADATA.en.distribute,
        METADATA.en.develop,
        YOUTUBE_RESOURCES,
        BLOGGER_RESOURCES,
        METADATA.en.extras
      );
    }

    // Merge local language resources.
    if (locale !== 'en' && METADATA[locale]) {
      if (useDevsiteMetadata) {
        all_keys = Object.keys(METADATA[locale]);
        $(all_keys).each(function(index, category) {
          if (RESERVED_METADATA_CATEGORY_NAMES.indexOf(category) == -1) {
            METADATA.all = mergeArrays(
              METADATA.all,
              METADATA.en[category]
            );
          }
        });

        METADATA.all = mergeArrays(
          METADATA.all,
          METADATA[locale].extras
        );
      } else {
        METADATA.all = mergeArrays(
          METADATA.all,
          METADATA[locale].about,
          METADATA[locale].design,
          METADATA[locale].distribute,
          METADATA[locale].develop,
          METADATA[locale].extras
        );

      }
    }

    mergeMetadataMap('collections', locale);
    mergeMetadataMap('searchHeroCollections', locale);
    mergeMetadataMap('carousel', locale);

    // Create query indicies for resources.
    createIndices(METADATA.all, locale);

    // Reference metadata.
    METADATA.androidReference = mergeArrays(
        window.DATA, window.SUPPORT_WEARABLE_DATA, window.SUPPORT_TEST_DATA);
    METADATA.googleReference = mergeArrays(window.GMS_DATA, window.GCM_DATA);
  };
})();

/* global METADATA, util */
window.metadata.query = (function($) {
  var pageMap = {};

  function buildResourceList(opts) {
    window.metadata.prepare();
    var expressions = parseResourceQuery(opts.query || '');
    var instanceMap = {};
    var results = [];

    for (var i = 0; i < expressions.length; i++) {
      var clauses = expressions[i];

      // Get all resources for first clause
      var resources = getResourcesForClause(clauses.shift());

      // Concat to final results list
      results = results.concat(resources.map(filterResources(clauses, i > 0, instanceMap)).filter(filterEmpty));
    }

    // Set correct order
    if (opts.sortOrder && results.length) {
      results = opts.sortOrder === 'random' ? util.shuffle(results) : results.sort(sortResultsByKey(opts.sortOrder));
    }

    // Slice max results.
    if (opts.maxResults !== Infinity) {
      results = results.slice(0, opts.maxResults);
    }

    // Remove page level duplicates
    if (opts.allowDuplicates === undefined || opts.allowDuplicates === 'false') {
      results = results.filter(removePageLevelDuplicates);

      for (var index = 0; index < results.length; ++index) {
        pageMap[results[index].index] = 1;
      }
    }

    return results;
  }

  function filterResources(clauses, removeDuplicates, map) {
    return function(resource) {
      var resourceIsAllowed = true;

      // References must be defined.
      if (resource === undefined) {
        return;
      }

      // Get canonical (localized) version of resource if possible.
      resource = METADATA.byUrl[resource.baseUrl] || METADATA.byUrl[resource.url] || resource;

      // Filter out resources already used
      if (removeDuplicates) {
        resourceIsAllowed = !map[resource.index];
      }

      // Must fulfill all criteria
      if (clauses.length > 0) {
        resourceIsAllowed = resourceIsAllowed && doesResourceMatchClauses(resource, clauses);
      }

      // Mark resource as used.
      if (resourceIsAllowed) {
        map[resource.index] = 1;
      }

      return resourceIsAllowed && resource;
    };
  }

  function filterEmpty(resource) {
    return resource;
  }

  function sortResultsByKey(key) {
    var desc = key.charAt(0) === '-';

    if (desc) {
      key = key.substring(1);
    }

    return function(x, y) {
      return (desc ? -1 : 1) * (parseInt(x[key], 10) - parseInt(y[key], 10));
    };
  }

  function getResourcesForClause(clause) {
    switch (clause.attr) {
      case 'type':
        return METADATA.byType[clause.value];
      case 'tag':
        return METADATA.byTag[clause.value];
      case 'collection':
        var resources = METADATA.collections[clause.value] || {};
        return getResourcesByUrlCollection(resources.resources);
      case 'history':
        return getResourcesByUrlCollection($.dacGetVisitedUrls(clause.value));
      case 'section':
        return getResourcesByUrlCollection([clause.value].sections);
      default:
        return [];
    }
  }

  function getResourcesByUrlCollection(resources) {
    return (resources || []).map(function(url) {
      return METADATA.byUrl[url];
    });
  }

  function removePageLevelDuplicates(resource) {
    return resource && !pageMap[resource.index];
  }

  function doesResourceMatchClauses(resource, clauses) {
    for (var i = 0; i < clauses.length; i++) {
      var map;
      switch (clauses[i].attr) {
        case 'type':
          map = METADATA.hasType[clauses[i].value];
          break;
        case 'tag':
          map = METADATA.hasTag[clauses[i].value];
          break;
      }

      if (!map || (!!clauses[i].negative ? map[resource.index] : !map[resource.index])) {
        return clauses[i].negative;
      }
    }

    return true;
  }

  function parseResourceQuery(query) {
    // Parse query into array of expressions (expression e.g. 'tag:foo + type:video')
    var expressions = [];
    var expressionStrs = query.split(',') || [];
    for (var i = 0; i < expressionStrs.length; i++) {
      var expr = expressionStrs[i] || '';

      // Break expression into clauses (clause e.g. 'tag:foo')
      var clauses = [];
      var clauseStrs = expr.split(/(?=[\+\-])/);
      for (var j = 0; j < clauseStrs.length; j++) {
        var clauseStr = clauseStrs[j] || '';

        // Get attribute and value from clause (e.g. attribute='tag', value='foo')
        var parts = clauseStr.split(':');
        var clause = {};

        clause.attr = parts[0].replace(/^\s+|\s+$/g, '');
        if (clause.attr) {
          if (clause.attr.charAt(0) === '+') {
            clause.attr = clause.attr.substring(1);
          } else if (clause.attr.charAt(0) === '-') {
            clause.negative = true;
            clause.attr = clause.attr.substring(1);
          }
        }

        if (parts.length > 1) {
          clause.value = parts[1].replace(/^\s+|\s+$/g, '');
        }

        clauses.push(clause);
      }

      if (!clauses.length) {
        continue;
      }

      expressions.push(clauses);
    }

    return expressions;
  }

  return buildResourceList;
})(jQuery);

/* global METADATA, getLangPref */

window.metadata.search = (function() {
  'use strict';

  var currentLang = getLangPref();

  function search(query) {
    window.metadata.prepare();
    return {
      android: findDocsMatches(query, METADATA.androidReference),
      docs: findDocsMatches(query, METADATA.googleReference),
      resources: findResourceMatches(query)
    };
  }

  function findDocsMatches(query, data) {
    var results = [];

    for (var i = 0; i < data.length; i++) {
      var s = data[i];
      if (query.length !== 0 && s.label.toLowerCase().indexOf(query.toLowerCase()) !== -1) {
        results.push(s);
      }
    }

    rankAutocompleteApiResults(query, results);

    return results;
  }

  function findResourceMatches(query) {
    var results = [];

    // Search for matching JD docs
    if (query.length >= 2) {
      /* In some langs, spaces may be optional between certain non-Ascii word-glyphs. For
       * those langs, only match query at word boundaries if query includes Ascii chars only.
       */
      var NO_BOUNDARY_LANGUAGES = ['ja','ko','vi','zh-cn','zh-tw'];
      var isAsciiOnly = /^[\u0000-\u007f]*$/.test(query);
      var noBoundaries = (NO_BOUNDARY_LANGUAGES.indexOf(window.getLangPref()) !== -1);
      var exprBoundary = (!isAsciiOnly && noBoundaries) ? '' : '(?:^|\\s)';
      var queryRegex = new RegExp(exprBoundary + query.toLowerCase(), 'g');

      var all = METADATA.all;
      for (var i = 0; i < all.length; i++) {
        // current search comparison, with counters for tag and title,
        // used later to improve ranking
        var s = all[i];
        s.matched_tag = 0;
        s.matched_title = 0;
        var matched = false;

        // Check if query matches any tags; work backwards toward 1 to assist ranking
        if (s.keywords) {
          for (var j = s.keywords.length - 1; j >= 0; j--) {
            // it matches a tag
            if (s.keywords[j].toLowerCase().match(queryRegex)) {
              matched = true;
              s.matched_tag = j + 1; // add 1 to index position
            }
          }
        }

        // Check if query matches doc title
        if (s.title.toLowerCase().match(queryRegex)) {
          matched = true;
          s.matched_title = 1;
        }

        // Remember the doc if it matches either
        if (matched) {
          results.push(s);
        }
      }

      // Improve the current results
      results = lookupBetterResult(results);

      // Rank/sort all the matched pages
      rankAutocompleteDocResults(results);

      return results;
    }
  }

  // Replaces a match with another resource by url, if it exists.
  function lookupReplacementByUrl(match, url) {
    var replacement = METADATA.byUrl[url];

    // Replacement resource does not exists.
    if (!replacement) { return; }

    replacement.matched_title = Math.max(replacement.matched_title, match.matched_title);
    replacement.matched_tag = Math.max(replacement.matched_tag, match.matched_tag);

    return replacement;
  }

  // Find the localized version of a page if it exists.
  function lookupLocalizedVersion(match) {
    return METADATA.byUrl[match.baseUrl] || METADATA.byUrl[match.url];
  }

  // Find the main page for a tutorial when matching a subpage.
  function lookupTutorialIndex(match) {
    // Guard for non index tutorial pages.
    if (match.type !== 'training' || match.url.indexOf('index.html') >= 0) { return; }

    var indexUrl = match.url.replace(/[^\/]+$/, 'index.html');
    return lookupReplacementByUrl(match, indexUrl);
  }

  // Find related results which are a better match for the user.
  function lookupBetterResult(matches) {
    var newMatches = [];

    matches = matches.filter(function(match) {
      var newMatch = match;
      newMatch = lookupTutorialIndex(newMatch) || newMatch;
      newMatch = lookupLocalizedVersion(newMatch) || newMatch;

      if (newMatch !== match) {
        newMatches.push(newMatch);
      }

      return newMatch === match;
    });

    return toUnique(newMatches.concat(matches));
  }

  /* Order the jd doc result list based on match quality */
  function rankAutocompleteDocResults(matches) {
    if (!matches || !matches.length) {
      return;
    }

    var _resultScoreFn = function(match) {
      var score = 1.0;

      // if the query matched a tag
      if (match.matched_tag > 0) {
        // multiply score by factor relative to position in tags list (max of 3)
        score *= 3 / match.matched_tag;

        // if it also matched the title
        if (match.matched_title > 0) {
          score *= 2;
        }
      } else if (match.matched_title > 0) {
        score *= 3;
      }

      if (match.lang === currentLang) {
        score *= 5;
      }

      return score;
    };

    for (var i = 0; i < matches.length; i++) {
      matches[i].__resultScore = _resultScoreFn(matches[i]);
    }

    matches.sort(function(a, b) {
      var n = b.__resultScore - a.__resultScore;

      if (n === 0) {
        // lexicographical sort if scores are the same
        n = (a.title < b.title) ? -1 : 1;
      }

      return n;
    });
  }

  /* Order the result list based on match quality */
  function rankAutocompleteApiResults(query, matches) {
    query = query || '';
    if (!matches || !matches.length) {
      return;
    }

    // helper function that gets the last occurence index of the given regex
    // in the given string, or -1 if not found
    var _lastSearch = function(s, re) {
      if (s === '') {
        return -1;
      }
      var l = -1;
      var tmp;
      while ((tmp = s.search(re)) >= 0) {
        if (l < 0) {
          l = 0;
        }
        l += tmp;
        s = s.substr(tmp + 1);
      }
      return l;
    };

    // helper function that counts the occurrences of a given character in
    // a given string
    var _countChar = function(s, c) {
      var n = 0;
      for (var i = 0; i < s.length; i++) {
        if (s.charAt(i) === c) {
          ++n;
        }
      }
      return n;
    };

    var queryLower = query.toLowerCase();
    var queryAlnum = (queryLower.match(/\w+/) || [''])[0];
    var partPrefixAlnumRE = new RegExp('\\b' + queryAlnum);
    var partExactAlnumRE = new RegExp('\\b' + queryAlnum + '\\b');

    var _resultScoreFn = function(result) {
      // scores are calculated based on exact and prefix matches,
      // and then number of path separators (dots) from the last
      // match (i.e. favoring classes and deep package names)
      var score = 1.0;
      var labelLower = result.label.toLowerCase();
      var t;
      var partsAfter;
      t = _lastSearch(labelLower, partExactAlnumRE);
      if (t >= 0) {
        // exact part match
        partsAfter = _countChar(labelLower.substr(t + 1), '.');
        score *= 200 / (partsAfter + 1);
      } else {
        t = _lastSearch(labelLower, partPrefixAlnumRE);
        if (t >= 0) {
          // part prefix match
          partsAfter = _countChar(labelLower.substr(t + 1), '.');
          score *= 20 / (partsAfter + 1);
        }
      }

      return score;
    };

    for (var i = 0; i < matches.length; i++) {
      // if the API is deprecated, default score is 0; otherwise, perform scoring
      if (matches[i].deprecated === 'true') {
        matches[i].__resultScore = 0;
      } else {
        matches[i].__resultScore = _resultScoreFn(matches[i]);
      }
    }

    matches.sort(function(a, b) {
      var n = b.__resultScore - a.__resultScore;

      if (n === 0) {
        // lexicographical sort if scores are the same
        n = (a.label < b.label) ? -1 : 1;
      }

      return n;
    });
  }

  // Destructive but fast toUnique.
  // http://stackoverflow.com/a/25082874
  function toUnique(array) {
    var c;
    var b = array.length || 1;

    while (c = --b) {
      while (c--) {
        if (array[b] === array[c]) {
          array.splice(c, 1);
        }
      }
    }
    return array;
  }

  return search;
})();

(function($) {
  'use strict';

  /**
   * Smoothly scroll to location on current page.
   * @param el
   * @param options
   * @constructor
   */
  function ScrollButton(el, options) {
    this.el = $(el);
    this.target = $(this.el.attr('href'));
    this.options = $.extend({}, ScrollButton.DEFAULTS_, options);

    if (typeof this.options.offset === 'string') {
      this.options.offset = $(this.options.offset).height();
    }

    this.el.on('click', this.clickHandler_.bind(this));
  }

  /**
   * Default options
   * @type {{duration: number, easing: string, offset: number, scrollContainer: string}}
   * @private
   */
  ScrollButton.DEFAULTS_ = {
    duration: 300,
    easing: 'swing',
    offset: '.dac-header',
    scrollContainer: 'html, body'
  };

  /**
   * Scroll logic
   * @param event
   * @private
   */
  ScrollButton.prototype.clickHandler_ = function(event) {
    if (event.altKey || event.ctrlKey || event.metaKey || event.shiftKey) {
      return;
    }

    event.preventDefault();

    var position = this.getTargetPosition();
    $(this.options.scrollContainer).animate({
      scrollTop: position - this.options.offset
    }, this.options);
  };

  ScrollButton.prototype.getTargetPosition = function() {
    if (this.options.scrollContainer === ScrollButton.DEFAULTS_.scrollContainer) {
      return this.target.offset().top;
    }
    var scrollContainer = $(this.options.scrollContainer)[0];
    var currentEl = this.target[0];
    var pos = 0;
    while (currentEl !== scrollContainer && currentEl !== null) {
      pos += currentEl.offsetTop;
      currentEl = currentEl.offsetParent;
    }
    return pos;
  };

  /**
   * jQuery plugin
   * @param  {object} options - Override default options.
   */
  $.fn.dacScrollButton = function(options) {
    return this.each(function() {
      new ScrollButton(this, options);
    });
  };

  /**
   * Data Attribute API
   */
  $(document).on('ready.aranja', function() {
    $('[data-scroll-button]').each(function() {
      $(this).dacScrollButton($(this).data());
    });
  });
})(jQuery);

/* global getLangPref */
(function($) {
  var LANG;

  function getSearchLang() {
    if (!LANG) {
      LANG = getLangPref();

      // Fix zh-cn to be zh-CN.
      LANG = LANG.replace(/-\w+/, function(m) { return m.toUpperCase(); });
    }
    return LANG;
  }

  function customSearch(query, start) {
    var searchParams = {
      // current cse instance:
      //cx: '001482626316274216503:zu90b7s047u',
      // new cse instance:
      cx: '000521750095050289010:zpcpi1ea4s8',
      key: 'AIzaSyCFhbGnjW06dYwvRCU8h_zjdpS4PYYbEe8',
      q: query,
      start: start || 1,
      num: 9,
      hl: getSearchLang(),
      fields: 'queries,items(pagemap,link,title,htmlSnippet,formattedUrl)'
    };

    return $.get('https://content.googleapis.com/customsearch/v1?' +  $.param(searchParams));
  }

  function renderResults(el, results, searchAppliance) {
    var referenceResults = searchAppliance.getReferenceResults();
    if (!results.items) {
      el.append($('<div>').text('No results'));
      return;
    }

    for (var i = 0; i < results.items.length; i++) {
      var item = results.items[i];
      var isDuplicate = false;
      $(referenceResults.android).each(function(index, result) {
        if (item.link.indexOf(result.link) > -1) {
          isDuplicate = true;
          return false;
        }
      });

      if (!isDuplicate) {
        var hasImage = item.pagemap && item.pagemap.cse_thumbnail;
        var sectionMatch = item.link.match(/developer\.android\.com\/(\w*)/);
        var section = (sectionMatch && sectionMatch[1]) || 'blog';

        var entry = $('<div>').addClass('dac-custom-search-entry cols');

        if (hasImage) {
          var image = item.pagemap.cse_thumbnail[0];
          entry.append($('<div>').addClass('dac-custom-search-image-wrapper')
            .append($('<div>').addClass('dac-custom-search-image').css('background-image', 'url(' + image.src + ')')));
        }

        entry.append($('<div>').addClass('dac-custom-search-text-wrapper')
          .append($('<p>').addClass('dac-custom-search-section').text(section))
          .append(
            $('<a>').text(item.title).attr('href', item.link).wrap('<h2>').parent().addClass('dac-custom-search-title')
          )
          .append($('<p>').addClass('dac-custom-search-snippet').html(item.htmlSnippet.replace(/<br>/g, '')))
          .append($('<a>').addClass('dac-custom-search-link').text(item.formattedUrl).attr('href', item.link)));

        el.append(entry);
      }
    }

    if (results.queries.nextPage) {
      var loadMoreButton = $('<button id="dac-custom-search-load-more">')
        .addClass('dac-custom-search-load-more')
        .text('Load more')
        .click(function() {
          loadMoreResults(el, results, searchAppliance);
        });

      el.append(loadMoreButton);
    }
  };

  function loadMoreResults(el, results, searchAppliance) {
    var query = results.queries.request[0].searchTerms;
    var start = results.queries.nextPage[0].startIndex;
    var loadMoreButton = el.find('#dac-custom-search-load-more');

    loadMoreButton.text('Loading more...');

    customSearch(query, start).then(function(results) {
      loadMoreButton.remove();
      renderResults(el, results, searchAppliance);
    });
  }

  $.fn.customSearch = function(query, searchAppliance) {
    var el = $(this);

    customSearch(query).then(function(results) {
      el.empty();
      renderResults(el, results, searchAppliance);
    });
  };
})(jQuery);

/* global METADATA */

(function($) {
  $.fn.dacSearchRenderHero = function(resources, query) {
    var el = $(this);
    el.empty();

    var resource = METADATA.searchHeroCollections[query];

    if (resource) {
      el.dacHero(resource, true);
      el.show();

      return true;
    } else {
      el.hide();
    }
  };
})(jQuery);

(function($) {
  $.fn.dacSearchRenderReferences = function(results, query) {
    var referenceCard = $('.suggest-card.reference');
    referenceCard.data('searchreferences.dac', {results: results, query: query});
    renderResults(referenceCard, results, query, false);
  };

  var ROW_COUNT_COLLAPSED = 20;
  var ROW_COUNT_EXPANDED = 40;
  var ROW_COUNT_GOOGLE_COLLAPSED = 1;
  var ROW_COUNT_GOOGLE_EXPANDED = 8;

  function onSuggestionClick(e) {
    devsite.analytics.trackAnalyticsEvent('event',
        'Suggestion Click', 'clicked: ' + $(e.currentTarget).attr('href'),
        'query: ' + $('#search_autocomplete').val().toLowerCase());
  }

  function buildLink(match) {
    var link = $('<a>').attr('href', window.toRoot + match.link);

    var label = match.label;
    var classNameStart = label.match(/[A-Z]/) ? label.search(/[A-Z]/) : label.lastIndexOf('.') + 1;
    var newLink = '<span class="namespace">' +
      label.substr(0, classNameStart) +
      '</span>' +
      label.substr(classNameStart, label.length);

    link.html(newLink);
    return link;
  }

  function buildSuggestion(match, query) {
    var li = $('<li>').addClass('dac-search-results-reference-entry');

    var link = buildLink(match);
    link.highlightMatches(query);
    li.append(link);
    return li[0];
  }

  function buildResults(results, query) {
    return results.map(function(match) {
      return buildSuggestion(match, query);
    });
  }

  function renderAndroidResults(list, gMatches, query) {
    list.empty();

    var header = $('<li class="dac-search-results-reference-header">android APIs</li>');
    list.append(header);

    if (gMatches.length > 0) {
      list.removeClass('no-results');

      var resources = buildResults(gMatches, query);
      list.append(resources);
      return true;
    } else {
      list.append('<li class="dac-search-results-reference-entry-empty">No results</li>');
    }
  }

  function renderGoogleDocsResults(list, gGoogleMatches, query) {
    list = $('.suggest-card.reference ul');

    if (gGoogleMatches.length > 0) {
      list.append('<li class="dac-search-results-reference-header">in Google Services</li>');

      var resources = buildResults(gGoogleMatches, query);
      list.append(resources);

      return true;
    }
  }

  function renderResults(referenceCard, results, query, expanded) {
    var list = referenceCard.find('ul');
    list.toggleClass('is-expanded', !!expanded);

    // Figure out how many results we can show in our fixed size box.
    var total = expanded ? ROW_COUNT_EXPANDED : ROW_COUNT_COLLAPSED;
    var googleCount = expanded ? ROW_COUNT_GOOGLE_EXPANDED : ROW_COUNT_GOOGLE_COLLAPSED;
    googleCount = Math.max(googleCount, total - results.android.length);
    googleCount = Math.min(googleCount, results.docs.length);

    if (googleCount > 0) {
      // If there are google results, reserve space for its header.
      googleCount++;
    }

    var androidCount = Math.max(0, total - googleCount);
    if (androidCount === 0) {
      // Reserve space for "No reference results"
      googleCount--;
    }

    renderAndroidResults(list, results.android.slice(0, androidCount), query);
    renderGoogleDocsResults(list, results.docs.slice(0, googleCount - 1), query);

    var totalResults = results.android.length + results.docs.length;
    if (totalResults === 0) {
      list.addClass('no-results');
    }

    // Tweak see more logic to account for references.
    var hasMore = totalResults > ROW_COUNT_COLLAPSED && !util.matchesMedia('mobile');
    if (hasMore) {
      // We can't actually show all matches, only as many as the expanded list
      // will fit, so we actually lie if the total results count is more
      var moreCount = Math.min(totalResults, ROW_COUNT_EXPANDED + ROW_COUNT_GOOGLE_EXPANDED);
      var $moreLink = $('<li class="dac-search-results-reference-entry-empty " data-toggle="show-more">see more matches</li>');
      list.append($moreLink.on('click', onToggleMore));
    }
    var searchEl = $('#search-resources');
    searchEl.toggleClass('dac-has-more', searchEl.hasClass('dac-has-more') || (hasMore && !expanded));
    searchEl.toggleClass('dac-has-less', searchEl.hasClass('dac-has-less') || (hasMore && expanded));
  }

  function onToggleMore(e) {
    var link = $(e.currentTarget);
    var referenceCard = $('.suggest-card.reference');
    var data = referenceCard.data('searchreferences.dac');

    if (util.matchesMedia('mobile')) { return; }

    renderResults(referenceCard, data.results, data.query, link.data('toggle') === 'show-more');
  }

  $(document).on('click', '.dac-search-results-resources [data-toggle="show-more"]', onToggleMore);
  $(document).on('click', '.dac-search-results-resources [data-toggle="show-less"]', onToggleMore);
  $(document).on('click', '.suggest-card.reference a', onSuggestionClick);
})(jQuery);

(function($) {
  function highlightPage(query, page) {
    page.find('.title').highlightMatches(query);
  }

  $.fn.dacSearchRenderResources = function(gDocsMatches, query) {
    this.resourceWidget(gDocsMatches, {
      itemsPerPage: 18,
      initialResults: 6,
      cardSizes: ['6x2'],
      onRenderPage: highlightPage.bind(null, query)
    });

    return this;
  };
})(jQuery);

/*global metadata */

(function($, metadata) {
  'use strict';

  function Search() {
    this.body = $('body');
    this.lastQuery = null;
    this.searchResults = $('#search-results');
    this.searchClose = $('[data-search-close]');
    this.searchClear = $('[data-search-clear]');
    this.searchInput = $('#search_autocomplete');
    this.searchResultsContent = $('#dac-search-results-content');
    this.searchResultsFor = $('#search-results-for');
    this.searchResultsHistory = $('#dac-search-results-history');
    this.searchResultsResources = $('#search-resources');
    this.searchResultsHero = $('#dac-search-results-hero');
    this.searchResultsReference = $('#dac-search-results-reference');
    this.searchHeader = $('[data-search]').data('search-input.dac');
    this.pageNav = $('a[name=navigation]');
    this.currQueryReferenceResults = {};
    this.isOpen = false;
  }

  Search.prototype.init = function() {
    this.searchHistory = window.dacStore('search-history');

    this.searchInput.focus(this.onSearchChanged.bind(this));
    this.searchInput.keypress(this.handleKeyboardShortcut.bind(this));
    this.pageNav.keyup(this.handleTabbedToNav.bind(this));
    this.searchResults.keyup(this.handleKeyboardShortcut.bind(this));
    this.searchInput.on('input', this.onSearchChanged.bind(this));
    this.searchClear.click(this.clear.bind(this));
    this.searchClose.click(this.close.bind(this));

    this.customSearch = $.fn.debounce(function(query) {
      $('#dac-custom-search-results').customSearch(query, this);
    }.bind(this), 1000);
    // Start search shortcut (/)
    $('body').keyup(function(event) {
      if (event.which === 191 && $(event.target).is(':not(:input)')) {
        this.searchInput.focus();
      }
    }.bind(this));

    $(window).on('popstate', this.onPopState.bind(this));
    $(window).hashchange(this.onHashChange.bind(this));
    this.onHashChange();
  };

  Search.prototype.checkRedirectToIndex = function() {
    var query = this.getUrlQuery();
    var target = window.getLangTarget();
    var prefix = (target !== 'en') ? '/intl/' + target : '';
    var pathname = location.pathname.slice(prefix.length);
    if (query != null && pathname !== '/index.html') {
      location.href = prefix + '/index.html' + location.hash;
      return true;
    }
  };

  Search.prototype.handleKeyboardShortcut = function(event) {
    // Close (esc)
    if (event.which === 27) {
      this.searchClose.trigger('click');
      event.preventDefault();
    }

    // Previous result (up arrow)
    if (event.which === 38) {
      this.previousResult();
      event.preventDefault();
    }

    // Next result (down arrow)
    if (event.which === 40) {
      this.nextResult();
      event.preventDefault();
    }

    // Navigate to result (enter)
    if (event.which === 13) {
      this.navigateToResult();
      event.preventDefault();
    }
  };

  Search.prototype.handleTabbedToNav = function(event) {
    if (this.isOpen) {
      this.searchClose.trigger('click');
    }
  }

  Search.prototype.goToResult = function(relativeIndex) {
    var links = this.searchResults.find('a').filter(':visible');
    var selectedLink = this.searchResults.find('.dac-selected');

    if (selectedLink.length) {
      var found = $.inArray(selectedLink[0], links);

      selectedLink.removeClass('dac-selected');
      links.eq(found + relativeIndex).addClass('dac-selected');
      return true;
    } else {
      if (relativeIndex > 0) {
        links.first().addClass('dac-selected');
      }
    }
  };

  Search.prototype.previousResult = function() {
    this.goToResult(-1);
  };

  Search.prototype.nextResult = function() {
    this.goToResult(1);
  };

  Search.prototype.navigateToResult = function() {
    var query = this.getQuery();
    var selectedLink = this.searchResults.find('.dac-selected');

    if (selectedLink.length) {
      selectedLink[0].click();
    } else {
      this.searchHistory.push(query);
      this.addQueryToUrl(query);

      var isMobileOrTablet = typeof window.orientation !== 'undefined';

      if (isMobileOrTablet) {
        this.searchInput.blur();
      }
    }
  };

  Search.prototype.onHashChange = function() {
    var query = this.getUrlQuery();
    if (query != null && query !== this.getQuery()) {
      this.searchInput.val(query);
      this.onSearchChanged();
    }
  };

  Search.prototype.clear = function() {
    this.searchInput.val('');
    window.location.hash = '';
    this.onSearchChanged();
    this.searchInput.focus();
  };

  Search.prototype.close = function() {
    this.removeQueryFromUrl();
    this.searchInput.blur();
    this.hideOverlay();
    this.pageNav.focus();
    this.isOpen = false;
  };

  Search.prototype.getUrlQuery = function() {
    var queryMatch = location.hash.match(/q=(.*)&?/);
    return queryMatch && queryMatch[1] && decodeURI(queryMatch[1]);
  };

  Search.prototype.getQuery = function() {
    return this.searchInput.val().replace(/(^ +)|( +$)/g, '');
  };

  Search.prototype.getReferenceResults = function() {
    return this.currQueryReferenceResults;
  };

  Search.prototype.onSearchChanged = function() {
    var query = this.getQuery();

    this.showOverlay();
    this.render(query);
  };

  Search.prototype.render = function(query) {
    if (this.lastQuery === query) { return; }

    if (query.length < 2) {
      query = '';
    }

    this.lastQuery = query;
    this.searchResultsFor.text(query);

    // CSE results lag behind the metadata/reference results. We need to empty
    // the CSE results and add 'Loading' text so user's aren't looking at two
    // different sets of search results at one time.
    var $loadingEl =
        $('<div class="loadingCustomSearchResults">Loading Results...</div>');
    $('#dac-custom-search-results').empty().prepend($loadingEl);

    this.customSearch(query);
    var metadataResults = metadata.search(query);
    this.searchResultsResources.dacSearchRenderResources(metadataResults.resources, query);
    this.searchResultsReference.dacSearchRenderReferences(metadataResults, query);
    this.currQueryReferenceResults = metadataResults;
    var hasHero = this.searchResultsHero.dacSearchRenderHero(metadataResults.resources, query);
    var hasQuery = !!query;

    this.searchResultsReference.toggle(!hasHero);
    this.searchResultsContent.toggle(hasQuery);
    this.searchResultsHistory.toggle(!hasQuery);
    this.addQueryToUrl(query);
    this.pushState();
  };

  Search.prototype.addQueryToUrl = function(query) {
    var hash = 'q=' + encodeURI(query);

    if (query) {
      if (window.history.replaceState) {
        window.history.replaceState(null, '', '#' + hash);
      } else {
        window.location.hash = hash;
      }
    }
  };

  Search.prototype.onPopState = function() {
    if (!this.getUrlQuery()) {
      this.hideOverlay();
      this.searchHeader.unsetActiveState();
    }
  };

  Search.prototype.removeQueryFromUrl = function() {
    window.location.hash = '';
  };

  Search.prototype.pushState = function() {
    if (window.history.pushState && !this.lastQuery.length) {
      window.history.pushState(null, '');
    }
  };

  Search.prototype.showOverlay = function() {
    this.isOpen = true;
    this.body.addClass('dac-modal-open dac-search-open');
  };

  Search.prototype.hideOverlay = function() {
    this.body.removeClass('dac-modal-open dac-search-open');
  };

  $(document).on('ready.aranja', function() {
    var search = new Search();
    search.init();
  });
})(jQuery, metadata);

window.dacStore = (function(window) {
  /**
   * Creates a new persistent store.
   * If localStorage is unavailable, the items are stored in memory.
   *
   * @constructor
   * @param {string} name    The name of the store
   * @param {number} maxSize The maximum number of items the store can hold.
   */
  var Store = function(name, maxSize) {
    var content = [];

    var hasLocalStorage = !!window.localStorage;

    if (hasLocalStorage) {
      try {
        content = JSON.parse(window.localStorage.getItem(name) || []);
      } catch (e) {
        // Store contains invalid data
        window.localStorage.removeItem(name);
      }
    }

    function push(item) {
      if (content[0] === item) {
        return;
      }

      content.unshift(item);

      if (maxSize) {
        content.splice(maxSize, content.length);
      }

      if (hasLocalStorage) {
        window.localStorage.setItem(name, JSON.stringify(content));
      }
    }

    function all() {
      // Return a copy
      return content.slice();
    }

    return {
      push: push,
      all: all
    };
  };

  var stores = {
    'search-history': new Store('search-history', 3)
  };

  /**
   * Get a named persistent store.
   * @param  {string} name
   * @return {Store}
   */
  return function getStore(name) {
    return stores[name];
  };
})(window);

(function($) {
  'use strict';

  /**
   * A component that swaps two dynamic height views with an animation.
   * Listens for the following events:
   * * swap-content: triggers SwapContent.swap_()
   * * swap-reset: triggers SwapContent.reset()
   * @param el
   * @param options
   * @constructor
   */
  function SwapContent(el, options) {
    this.el = $(el);
    this.options = $.extend({}, SwapContent.DEFAULTS_, options);
    this.options.dynamic = this.options.dynamic === 'true';
    this.containers = this.el.find(this.options.container);
    this.initiallyActive = this.containers.children('.' + this.options.activeClass).eq(0);
    this.el.on('swap-content', this.swap.bind(this));
    this.el.on('swap-reset', this.reset.bind(this));
    this.el.find(this.options.swapButton).on('click keypress', function(e) {
      if (e.type == 'keypress' && e.which == 13 || e.type == 'click') {
        this.swap();
      }
    }.bind(this));
  }

  /**
   * SwapContent's default settings.
   * @type {{activeClass: string, container: string, transitionSpeed: number}}
   * @private
   */
  SwapContent.DEFAULTS_ = {
    activeClass: 'dac-active',
    container: '[data-swap-container]',
    dynamic: 'true',
    swapButton: '[data-swap-button]',
    transitionSpeed: 500
  };

  /**
   * Returns container's visible height.
   * @param container
   * @returns {number}
   */
  SwapContent.prototype.currentHeight = function(container) {
    return container.children('.' + this.options.activeClass).outerHeight();
  };

  /**
   * Reset to show initial content
   */
  SwapContent.prototype.reset = function() {
    if (!this.initiallyActive.hasClass(this.initiallyActive)) {
      this.containers.children().toggleClass(this.options.activeClass);
    }
  };

  /**
   * Complete the swap.
   */
  SwapContent.prototype.complete = function() {
    this.containers.height('auto');
    this.containers.trigger('swap-complete');
  };

  /**
   * Perform the swap of content.
   */
  SwapContent.prototype.swap = function() {
    this.containers.each(function(index, container) {
      container = $(container);

      if (!this.options.dynamic) {
        container.children().toggleClass(this.options.activeClass);
        this.complete.bind(this);
        $('.' + this.options.activeClass).focus();
        return;
      }

      container.height(this.currentHeight(container)).children().toggleClass(this.options.activeClass);
      container.animate({height: this.currentHeight(container)}, this.options.transitionSpeed,
        this.complete.bind(this));
    }.bind(this));
  };

  /**
   * jQuery plugin
   * @param  {object} options - Override default options.
   */
  $.fn.dacSwapContent = function(options) {
    return this.each(function() {
      new SwapContent(this, options);
    });
  };

  /**
   * Data Attribute API
   */
  $(document).on('ready.aranja', function() {
    $('[data-swap]').each(function() {
      $(this).dacSwapContent($(this).data());
    });
  });
})(jQuery);

/* Tabs */
(function($) {
  'use strict';

  /**
   * @param {HTMLElement} el - The DOM element.
   * @param {Object} options
   * @constructor
   */
  function Tabs(el, options) {
    this.el = $(el);
    this.options = $.extend({}, Tabs.DEFAULTS_, options);
    this.init();
  }

  Tabs.DEFAULTS_ = {
    activeClass: 'dac-active',
    viewDataAttr: 'tab-view',
    itemDataAttr: 'tab-item'
  };

  Tabs.prototype.init = function() {
    var itemDataAttribute = '[data-' + this.options.itemDataAttr + ']';
    this.tabEl_ = this.el.find(itemDataAttribute);
    this.tabViewEl_ = this.el.find('[data-' + this.options.viewDataAttr + ']');
    this.el.on('click.dac-tabs', itemDataAttribute, this.changeTabs.bind(this));
  };

  Tabs.prototype.changeTabs = function(event) {
    var current = $(event.currentTarget);
    var index = current.index();

    if (current.hasClass(this.options.activeClass)) {
      current.add(this.tabViewEl_.eq(index)).removeClass(this.options.activeClass);
    } else {
      this.tabEl_.add(this.tabViewEl_).removeClass(this.options.activeClass);
      current.add(this.tabViewEl_.eq(index)).addClass(this.options.activeClass);
    }
  };

  /**
   * jQuery plugin
   */
  $.fn.dacTabs = function() {
    return this.each(function() {
      var el = $(this);
      new Tabs(el, el.data());
    });
  };

  /**
   * Data Attribute API
   */
  $(function() {
    $('[data-tabs]').dacTabs();
  });
})(jQuery);

/* Toast Component */
(function($) {
  'use strict';
  /**
   * @constant
   * @type {String}
   */
  var LOCAL_STORAGE_KEY = 'toast-closed-index';

  /**
   * Dictionary from local storage.
   */
  var toastDictionary = localStorage.getItem(LOCAL_STORAGE_KEY);
  toastDictionary = toastDictionary ? JSON.parse(toastDictionary) : {};

  /**
   * Variable used for caching the body.
   */
  var bodyCached;

  /**
   * @param {HTMLElement} el - The DOM element.
   * @param {Object} options
   * @constructor
   */
  function Toast(el, options) {
    this.el = $(el);
    this.options = $.extend({}, Toast.DEFAULTS_, options);
    this.init();
  }

  Toast.DEFAULTS_ = {
    closeBtnClass: 'dac-toast-close-btn',
    closeDuration: 200,
    visibleClass: 'dac-visible',
    wrapClass: 'dac-toast-wrap'
  };

  /**
   * Generate a close button.
   * @returns {*|HTMLElement}
   */
  Toast.prototype.closeBtn = function() {
    this.closeBtnEl = this.closeBtnEl || $('<button class="' + this.options.closeBtnClass + '">' +
      '<span class="dac-button dac-raised dac-primary">OK</span>' +
    '</button>');
    return this.closeBtnEl;
  };

  /**
   * Initialize a new toast element
   */
  Toast.prototype.init = function() {
    this.hash = this.el.text().replace(/[\s\n\t]/g, '').split('').slice(0, 128).join('');

    if (toastDictionary[this.hash]) {
      return;
    }

    this.closeBtn().on('click', this.onClickHandler.bind(this));
    this.el.find('.' + this.options.wrapClass).append(this.closeBtn());
    this.el.addClass(this.options.visibleClass);
    this.dynamicPadding(this.el.outerHeight());
  };

  /**
   * Add padding to make sure all page is visible.
   */
  Toast.prototype.dynamicPadding = function(val) {
    var currentPadding = parseInt(bodyCached.css('padding-bottom') || 0);
    bodyCached.css('padding-bottom', val + currentPadding);
  };

  /**
   * Remove a toast from the DOM
   */
  Toast.prototype.remove = function() {
    this.dynamicPadding(-this.el.outerHeight());
    this.el.remove();
  };

  /**
   * Handle removal of the toast.
   */
  Toast.prototype.onClickHandler = function() {
    // Only fadeout toasts from top of stack. Others are removed immediately.
    var duration = this.el.index() === 0 ? this.options.closeDuration : 0;
    this.el.fadeOut(duration, this.remove.bind(this));

    // Save closed state.
    toastDictionary[this.hash] = 1;
    localStorage.setItem(LOCAL_STORAGE_KEY, JSON.stringify(toastDictionary));
  };

  /**
   * jQuery plugin
   * @param  {object} options - Override default options.
   */
  $.fn.dacToast = function() {
    return this.each(function() {
      var el = $(this);
      new Toast(el, el.data());
    });
  };

  /**
   * Data Attribute API
   */
  $(function() {
    bodyCached = $('#body-content');
    $('[data-toast]').dacToast();
  });
})(jQuery);

(function($) {
  function Toggle(el) {
    $(el).on('click.dac.togglesection', this.toggle);
  }

  Toggle.prototype.toggle = function() {
    var $this = $(this);

    var $parent = getParent($this);
    var isExpanded = $parent.hasClass('is-expanded');

    transitionMaxHeight($parent.find('.dac-toggle-content'), !isExpanded);
    $parent.toggleClass('is-expanded');

    return false;
  };

  function getParent($this) {
    var selector = $this.attr('data-target');

    if (!selector) {
      selector = $this.attr('href');
      selector = selector && /#[A-Za-z]/.test(selector) && selector.replace(/.*(?=#[^\s]*$)/, '');
    }

    var $parent = selector && $(selector);

    $parent = $parent && $parent.length ? $parent : $this.closest('.dac-toggle');

    return $parent.length ? $parent : $this.parent();
  }

  /**
   * Runs a transition of max-height along with responsive styles which hide or expand the element.
   * @param $el
   * @param visible
   */
  function transitionMaxHeight($el, visible) {
    var contentHeight = $el.prop('scrollHeight');
    var targetHeight = visible ? contentHeight : 0;
    var duration = $el.transitionDuration();

    // If we're hiding, first set the maxHeight we're transitioning from.
    if (!visible) {
      $el.css({
          transitionDuration: '0s',
          maxHeight: contentHeight + 'px'
        })
        .resolveStyles()
        .css('transitionDuration', '');
    }

    // Transition to new state
    $el.css('maxHeight', targetHeight);

    // Reset maxHeight to css value after transition.
    setTimeout(function() {
      $el.css({
          transitionDuration: '0s',
          maxHeight: ''
        })
        .resolveStyles()
        .css('transitionDuration', '');
    }, duration);
  }

  // Utility to get the transition duration for the element.
  $.fn.transitionDuration = function() {
    var d = $(this).css('transitionDuration') || '0s';

    return +(parseFloat(d) * (/ms/.test(d) ? 1 : 1000)).toFixed(0);
  };

  // jQuery plugin
  $.fn.toggleSection = function(option) {
    return this.each(function() {
      var $this = $(this);
      var data = $this.data('dac.togglesection');
      if (!data) {$this.data('dac.togglesection', (data = new Toggle(this)));}
      if (typeof option === 'string') {data[option].call($this);}
    });
  };

  // Data api
  $(document)
    .on('click.toggle', '[data-toggle="section"]', Toggle.prototype.toggle);
})(jQuery);

(function(window) {
  /**
   * Media query breakpoints. Should match CSS.
   */
  var BREAKPOINTS = {
    mobile: [0, 719],
    tablet: [720, 959],
    desktop: [960, 9999]
  };

  /**
   * Fisher-Yates Shuffle (Knuth shuffle).
   * @param {Array} input
   * @returns {Array} shuffled array.
   */
  function shuffle(input) {
    for (var i = input.length; i >= 0; i--) {
      var randomIndex = Math.floor(Math.random() * (i + 1));
      var randomItem = input[randomIndex];
      input[randomIndex] = input[i];
      input[i] = randomItem;
    }

    return input;
  }

  /**
   * Matches media breakpoints like in CSS.
   * @param {string} form of either mobile, tablet or desktop.
   */
  function matchesMedia(form) {
    var breakpoint = BREAKPOINTS[form];
    return window.innerWidth >= breakpoint[0] && window.innerWidth <= breakpoint[1];
  }

  window.util = {
    shuffle: shuffle,
    matchesMedia: matchesMedia
  };
})(window);

(function($, window) {
  'use strict';

  var YouTubePlayer = (function() {
    var player;

    function VideoPlayer() {
      this.mPlayerPaused = false;
      this.doneSetup = false;
    }

    VideoPlayer.prototype.setup = function() {
      // loads the IFrame Player API code asynchronously.
      $.getScript('https://www.youtube.com/iframe_api');

      // Add the shadowbox HTML to the body
      $('body').prepend(
'<div id="video-player" class="Video">' +
  '<div id="video-overlay" class="Video-overlay" />' +
  '<div class="Video-container">' +
    '<div class="Video-frame">' +
      '<span class="Video-loading">Loading&hellip;</span>' +
      '<div id="youTubePlayer"></div>' +
    '</div>' +
    '<div class="Video-controls">' +
      '<button id="picture-in-picture" class="Video-button Video-button--picture-in-picture">' +
      '<button id="close-video" class="Video-button Video-button--close" />' +
    '</div>' +
  '</div>' +
'</div>');

      this.videoPlayer = $('#video-player');

      var pictureInPictureButton = this.videoPlayer.find('#picture-in-picture');
      pictureInPictureButton.on('click.aranja', this.toggleMinimizeVideo.bind(this));

      var videoOverlay = this.videoPlayer.find('#video-overlay');
      var closeButton = this.videoPlayer.find('#close-video');
      var closeVideo = this.closeVideo.bind(this);
      videoOverlay.on('click.aranja', closeVideo);
      closeButton.on('click.aranja', closeVideo);

      this.doneSetup = true;
    };

    VideoPlayer.prototype.startYouTubePlayer = function(videoId) {
      this.videoPlayer.show();

      if (!this.isLoaded) {
        this.queueVideo = videoId;
        return;
      }

      this.mPlayerPaused = false;
      // check if we've already created this player
      if (!this.youTubePlayer) {
        // check if there's a start time specified
        var idAndHash = videoId.split('#');
        var startTime = 0;
        if (idAndHash.length > 1) {
          startTime = idAndHash[1].split('t=')[1] !== undefined ? idAndHash[1].split('t=')[1] : 0;
        }
        // enable localized player
        var lang = getLangPref();
        var captionsOn = lang === 'en' ? 0 : 1;

        this.youTubePlayer = new YT.Player('youTubePlayer', {
          height: 720,
          width: 1280,
          videoId: idAndHash[0],
          // jscs:disable requireCamelCaseOrUpperCaseIdentifiers
          playerVars: {start: startTime, hl: lang, cc_load_policy: captionsOn},
          // jscs:enable
          events: {
            'onReady': this.onPlayerReady.bind(this),
            'onStateChange': this.onPlayerStateChange.bind(this)
          }
        });
      } else {
        // if a video different from the one already playing was requested, cue it up
        if (videoId !== this.getVideoId()) {
          this.youTubePlayer.cueVideoById(videoId);
        }
        this.youTubePlayer.playVideo();
      }
    };

    VideoPlayer.prototype.onPlayerReady = function(event) {
      if (!isMobile) {
        event.target.playVideo();
        this.mPlayerPaused = false;
      }
    };

    VideoPlayer.prototype.toggleMinimizeVideo = function(event) {
      event.stopPropagation();
      this.videoPlayer.toggleClass('Video--picture-in-picture');
    };

    VideoPlayer.prototype.closeVideo = function() {
      try {
        this.youTubePlayer.pauseVideo();
      } catch (e) {
      }
      this.videoPlayer.fadeOut(200, function() {
        this.videoPlayer.removeClass('Video--picture-in-picture');
      }.bind(this));
    };

    VideoPlayer.prototype.getVideoId = function() {
      // jscs:disable requireCamelCaseOrUpperCaseIdentifiers
      return this.youTubePlayer && this.youTubePlayer.getVideoData().video_id;
      // jscs:enable
    };

    /* Track youtube playback for analytics */
    VideoPlayer.prototype.onPlayerStateChange = function(event) {
      var videoId = this.getVideoId();
      var currentTime = this.youTubePlayer && this.youTubePlayer.getCurrentTime();

      // Video starts, send the video ID
      if (event.data === YT.PlayerState.PLAYING) {
        if (this.mPlayerPaused) {
          devsite.analytics.trackAnalyticsEvent('event',
              'Videos', 'Resume', videoId);
        } else {
          // track the start playing event so we know from which page the video was selected
          devsite.analytics.trackAnalyticsEvent('event',
              'Videos', 'Start: ' + videoId, 'on: ' + document.location.href);
        }
        this.mPlayerPaused = false;
      }

      // Video paused, send video ID and video elapsed time
      if (event.data === YT.PlayerState.PAUSED) {
        devsite.analytics.trackAnalyticsEvent('event',
            'Videos', 'Paused: ' + videoId, 'on: ' + currentTime);
        this.mPlayerPaused = true;
      }

      // Video finished, send video ID and video elapsed time
      if (event.data === YT.PlayerState.ENDED) {
        devsite.analytics.trackAnalyticsEvent('event',
            'Videos', 'Finished: ' + videoId, 'on: ' + currentTime);
        this.mPlayerPaused = true;
      }
    };

    return {
      getPlayer: function() {
        if (!player) {
          player = new VideoPlayer();
        }

        return player;
      }
    };
  })();

  var videoPlayer = YouTubePlayer.getPlayer();

  window.onYouTubeIframeAPIReady = function() {
    videoPlayer.isLoaded = true;

    if (videoPlayer.queueVideo) {
      videoPlayer.startYouTubePlayer(videoPlayer.queueVideo);
    }
  };

  function wrapLinkInPlayer(e) {
    e.preventDefault();

    if (!videoPlayer.doneSetup) {
      videoPlayer.setup();
    }

    var videoIdMatches = $(e.currentTarget).attr('href').match(/(?:youtu.be\/|v=)([^&]*)/);
    var videoId = videoIdMatches && videoIdMatches[1];

    if (videoId) {
      videoPlayer.startYouTubePlayer(videoId);
    }
  }

  $(document).on('click.video', 'a[href*="youtube.com/watch"], a[href*="youtu.be"]', wrapLinkInPlayer);
})(jQuery, window);

/**
 * Wide table
 *
 * Wraps tables in a scrollable area so you can read them on mobile.
 */
(function($) {
  function initWideTable() {
    $('table.jd-sumtable').each(function(i, table) {
      $(table).wrap('<div class="dac-expand wide-table">');
    });
  }

  $(function() {
    initWideTable();
  });
})(jQuery);

/** Utilities */

/* returns the given string with all HTML brackets converted to entities
    TODO: move this to the site's JS library */
function escapeHTML(string) {
  return string.replace(/</g,"&lt;")
                .replace(/>/g,"&gt;");
};

function getQueryVariable(variable) {
  var query = window.location.search.substring(1);
  var vars = query.split("&");
  for (var i=0;i<vars.length;i++) {
    var pair = vars[i].split("=");
    if(pair[0] == variable){return pair[1];}
  }
  return(false);
};
