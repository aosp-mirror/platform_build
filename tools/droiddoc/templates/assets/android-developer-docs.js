var resizePackagesNav;
var classesNav;
var devdocNav;
var sidenav;
var content;
var HEADER_HEIGHT = 103;
var cookie_style = 'android_developer';
var NAV_PREF_TREE = "tree";
var NAV_PREF_PANELS = "panels";
var nav_pref;
var toRoot;


function addLoadEvent(newfun) {
  var current = window.onload;
  if (typeof window.onload != 'function') {
    window.onload = newfun;
  } else {
    window.onload = function() {
      current();
      newfun();
    }
  }
}

addLoadEvent(prepare);
window.onresize = resizeAll;

function setToRoot(root) {
  toRoot = root;
}

function restoreWidth(navWidth) {
  var windowWidth = $(window).width() + "px";
  content.css({marginLeft:navWidth, width:parseInt(windowWidth) - parseInt(navWidth) + "px"});
  sidenav.css({width:navWidth});
  resizePackagesNav.css({width:navWidth});
  classesNav.css({width:navWidth});
  $("#packages-nav").css({width:navWidth});
}

function restoreHeight(packageHeight) {
  var windowHeight = ($(window).height() - HEADER_HEIGHT);
  var swapperHeight = windowHeight - 13;
  $("#swapper").css({height:swapperHeight + "px"});
  sidenav.css({height:windowHeight + "px"});
  content.css({height:windowHeight + "px"});
  resizePackagesNav.css({maxHeight:swapperHeight + "px", height:packageHeight});
  classesNav.css({height:swapperHeight - parseInt(packageHeight) + "px"});
  $("#packages-nav").css({height:parseInt(packageHeight) - 6 + "px"}); //move 6px to give space for the resize handle
  devdocNav.css({height:sidenav.css("height")});
  $("#nav-tree").css({height:swapperHeight + "px"});
}

function getCookie(cookie) {
  var myCookie = cookie_style+"_"+cookie+"=";
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

function writeCookie(cookie, val, path, expiration) {
  if (!val) return;
  if (location.href.indexOf("/reference/") != -1) {
    document.cookie = cookie_style+'_reference_'+cookie+'='+ val+'; path=' + toRoot + path +
                                                           ((expiration) ? '; expires=' + expiration : '');
  } else if (location.href.indexOf("/guide/") != -1) {
    document.cookie = cookie_style+'_guide_'+cookie+'='+val+'; path=' + toRoot + path +
                                                           ((expiration) ? '; expires=' + expiration : '');
  }
} 

function prepare() {
  $("#side-nav").css({position:"absolute",left:0});
  content = $("#doc-content");
  resizePackagesNav = $("#resize-packages-nav");
  classesNav = $("#classes-nav");
  sidenav = $("#side-nav");
  devdocNav = $("#devdoc-nav");


  if (location.href.indexOf("/reference/") != -1) {
    var cookiePath = "reference_";
  } else if (location.href.indexOf("/guide/") != -1) {
    var cookiePath = "guide_";
  }
  var cookieWidth = getCookie(cookiePath+'width');
  var cookieHeight = getCookie(cookiePath+'height');
  if (cookieWidth) {
    restoreWidth(cookieWidth);
  } else {
    resizeWidth();
  }
  if (cookieHeight) {
    restoreHeight(cookieHeight);
  } else {
    resizeHeight();
  }

  if (devdocNav.length) { 
    highlightNav(location.href); 
  }
}

function highlightNav(fullPageName) {
  var lastSlashPos = fullPageName.lastIndexOf("/");
  var firstSlashPos = fullPageName.indexOf("/",8); // first slash after http://
  if (lastSlashPos == (fullPageName.length - 1)) { // if the url ends in slash (add 'index.html')
    fullPageName = fullPageName + "index.html";
  }
  var htmlPos = fullPageName.lastIndexOf(".html", fullPageName.length);
  var pathPageName = fullPageName.slice(firstSlashPos, htmlPos + 5);
  var link = $("#devdoc-nav a[href$='"+ pathPageName+"']");
  if (link.length == 0) { // if there's no match, then the nav url must be the parent dir (ie, this doc isn't listed, so highlight the parent
    link = $("#devdoc-nav a[href$='"+ pathPageName.slice(0, pathPageName.lastIndexOf("/") + 1)+"']");
  }
  link.parent().addClass('selected');
  if (link.parent().parent().is(':hidden')) {
    toggle(link.parent().parent().parent(), false);
  } else if (link.parent().parent().hasClass('toggle-list')) {
    toggle(link.parent().parent(), false);
  }
}

function resizeHeight() {
  var windowHeight = ($(window).height() - HEADER_HEIGHT);
  var swapperHeight = windowHeight - 13;
  $("#swapper").css({height:swapperHeight + "px"});
  sidenav.css({height:windowHeight + "px"});
  content.css({height:windowHeight + "px"});
  resizePackagesNav.css({maxHeight:swapperHeight + "px"});
  classesNav.css({height:swapperHeight - parseInt(resizePackagesNav.css("height")) + "px"});
  $("#packages-nav").css({height:parseInt(resizePackagesNav.css("height")) - 6 + "px"}); //move 6px for handle
  devdocNav.css({height:sidenav.css("height")});
  $("#nav-tree").css({height:swapperHeight + "px"});
  writeCookie("height", resizePackagesNav.css("height"), "reference/", null);
}

function resizeWidth() {
  if (location.href.indexOf("/reference/") != -1) {
    var path = "reference/";
  } else if (location.href.indexOf("/guide/") != -1) {
    var path = "guide/";
  }
  var windowWidth = $(window).width() + "px";
  if (sidenav.length) {
    var sidenavWidth = sidenav.css("width");
  } else {
    var sidenavWidth = 0;
  }
  content.css({marginLeft:sidenavWidth, width:parseInt(windowWidth) - parseInt(sidenavWidth) + "px"});
  resizePackagesNav.css({width:sidenavWidth});
  classesNav.css({width:sidenavWidth});
  $("#packages-nav").css({width:sidenavWidth});
  writeCookie("width", sidenavWidth, path, null);
}

function resizeAll() {
  resizeHeight();
  resizeWidth();
}

function loadLast(cookiePath) {
  var lastPage = getCookie(cookiePath + "_lastpage");
  if (lastPage) {
    window.location = lastPage;
    return false;
  }
  return true;
}

$(document).ready(function(){
  $("#resize-packages-nav").resizable({handles: "s", resize: function(e, ui) { resizeHeight(); } });
  $(".side-nav-resizable").resizable({handles: "e", resize: function(e, ui) { resizeWidth(); } });
});

$(window).unload(function(){
  var href = location.href;
  if (href.indexOf("/reference/") != -1) {
    writeCookie("lastpage", href, "", null);
  } else if (href.indexOf("/guide/") != -1) {
    writeCookie("lastpage", href, "", null);
  }
});




function toggle(obj, slide) {
  var ul = $("ul", obj);
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
      $("div", this).append("<a class='toggle-img' href='#' title='show pages' onClick='toggle(this.parentNode.parentNode, true); return false;'></a>");
      $(this).addClass("closed");
    });
}

function getNavPref() {
  var v = getCookie('reference_nav');
  if (v != NAV_PREF_TREE) {
    v = NAV_PREF_PANELS;
  }
  return v;
}

function chooseDefaultNav() {
  nav_pref = getNavPref();
  if (nav_pref == NAV_PREF_TREE) {
    $("#nav-panels").toggle();
    $("#panel-link").toggle();
    $("#nav-tree").toggle();
    $("#tree-link").toggle();
  }
}

function swapNav() {
  if (nav_pref == NAV_PREF_TREE) {
    nav_pref = NAV_PREF_PANELS;
  } else {
    nav_pref = NAV_PREF_TREE;
    init_navtree("nav-tree", toRoot, NAVTREE_DATA);
  }
  var date = new Date();
  date.setTime(date.getTime()+(10*365*24*60*60*1000)); // keep this for 10 years
  writeCookie("nav", nav_pref, "reference/", date.toGMTString());

  $("#nav-panels").toggle();
  $("#panel-link").toggle();
  $("#nav-tree").toggle();
  $("#tree-link").toggle();

  if ($("#nav-tree").is(':visible')) scrollIntoView("nav-tree");
  else {
    scrollIntoView("packages-nav");
    scrollIntoView("classes-nav");
  }
}

function scrollIntoView(nav) {
  var navObj = $("#"+nav);
  if (navObj.is(':visible')) {
    var selected = $(".selected", navObj);
    if (selected.length == 0) return;

    var scrolling = document.getElementById(nav);
    var navHeight = navObj.height();
    var offset = selected.position();
    if(offset.top > navHeight - 92) {
      scrolling.scrollTop = offset.top - navHeight + 92;
    }
  }
}


