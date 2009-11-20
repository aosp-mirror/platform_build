var resizePackagesNav;
var classesNav;
var devdocNav;
var sidenav;
var content;
var HEADER_HEIGHT = 117;
var cookie_namespace = 'android_developer';
var NAV_PREF_TREE = "tree";
var NAV_PREF_PANELS = "panels";
var nav_pref;
var toRoot;
var isMobile = false; // true if mobile, so we can adjust some layout
var isIE6 = false; // true if IE6

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

var agent = navigator['userAgent'].toLowerCase();
// If a mobile phone, set flag and do mobile setup
if ((agent.indexOf("mobile") != -1) ||      // android, iphone, ipod 
    (agent.indexOf("blackberry") != -1) ||
    (agent.indexOf("webos") != -1) ||
    (agent.indexOf("mini") != -1)) {        // opera mini browsers 
  isMobile = true;
  addLoadEvent(mobileSetup);
// If not a mobile browser, set the onresize event for IE6, and others
} else if (agent.indexOf("msie 6") != -1) {
  isIE6 = true;
  addLoadEvent(function() {
    window.onresize = resizeAll;
  });
} else {
  addLoadEvent(function() {
    window.onresize = resizeHeight;
  });
}

function mobileSetup() {
  $("body").css({'overflow':'auto'});
  $("html").css({'overflow':'auto'});
  $("#body-content").css({'position':'relative', 'top':'0'});
  $("#doc-content").css({'overflow':'visible', 'border-left':'3px solid #DDD'});
  $("#side-nav").css({'padding':'0'});
  $("#nav-tree").css({'overflow-y': 'auto'});
}

/* loads the lists.js file to the page.
Loading this in the head was slowing page load time */
addLoadEvent( function() {
  var lists = document.createElement("script");
  lists.setAttribute("type","text/javascript");
  lists.setAttribute("src", toRoot+"reference/lists.js");
  document.getElementsByTagName("head")[0].appendChild(lists);
} );

function setToRoot(root) {
  toRoot = root;
  // note: toRoot also used by carousel.js
}

function restoreWidth(navWidth) {
  var windowWidth = $(window).width() + "px";
  content.css({marginLeft:parseInt(navWidth) + 6 + "px"}); //account for 6px-wide handle-bar

  if (isIE6) {
    content.css({width:parseInt(windowWidth) - parseInt(navWidth) - 6 + "px"}); // necessary in order for scrollbars to be visible
  }

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

function readCookie(cookie) {
  var myCookie = cookie_namespace+"_"+cookie+"=";
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

function writeCookie(cookie, val, section, expiration) {
  if (val==undefined) return;
  section = section == null ? "_" : "_"+section+"_";
  if (expiration == null) {
    var date = new Date();
    date.setTime(date.getTime()+(10*365*24*60*60*1000)); // default expiration is one week
    expiration = date.toGMTString();
  }
  document.cookie = cookie_namespace + section + cookie + "=" + val + "; expires=" + expiration+"; path=/";
} 

function init() {
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

  if (!isMobile) {
    $("#resize-packages-nav").resizable({handles: "s", resize: function(e, ui) { resizePackagesHeight(); } });
    $(".side-nav-resizable").resizable({handles: "e", resize: function(e, ui) { resizeWidth(); } });
    var cookieWidth = readCookie(cookiePath+'width');
    var cookieHeight = readCookie(cookiePath+'height');
    if (cookieWidth) {
      restoreWidth(cookieWidth);
    } else if ($(".side-nav-resizable").length) {
      resizeWidth();
    }
    if (cookieHeight) {
      restoreHeight(cookieHeight);
    } else {
      resizeHeight();
    }
  }

  if (devdocNav.length) { // only dev guide and sdk 
    highlightNav(location.href); 
  }
}

function highlightNav(fullPageName) {
  var lastSlashPos = fullPageName.lastIndexOf("/");
  var firstSlashPos = (fullPageName.indexOf("/guide/") != -1) ?
                       fullPageName.indexOf("/guide/") : 
                       fullPageName.indexOf("/sdk/"); // first slash after /guide or /sdk
  if (lastSlashPos == (fullPageName.length - 1)) { // if the url ends in slash (add 'index.html')
    fullPageName = fullPageName + "index.html";
  }
  var htmlPos = fullPageName.lastIndexOf(".html", fullPageName.length);
  var pathPageName = fullPageName.slice(firstSlashPos, htmlPos + 5);
  var link = $("#devdoc-nav a[href$='"+ pathPageName+"']");
  if ((link.length == 0) && (fullPageName.indexOf("/guide/") != -1)) { 
// if there's no match, then let's backstep through the directory until we find an index.html page that matches our ancestor directories (only for dev guide)
    lastBackstep = pathPageName.lastIndexOf("/");
    while (link.length == 0) {
      backstepDirectory = pathPageName.lastIndexOf("/", lastBackstep);
      link = $("#devdoc-nav a[href$='"+ pathPageName.slice(0, backstepDirectory + 1)+"index.html']");
      lastBackstep = pathPageName.lastIndexOf("/", lastBackstep - 1);
      if (lastBackstep == 0) break;
    }
  }
  link.parent().addClass('selected');
  if (link.parent().parent().is(':hidden')) {
    toggle(link.parent().parent().parent(), false);
  } else if (link.parent().parent().hasClass('toggle-list')) {
    toggle(link.parent().parent(), false);
  }
}

/* Resize the height of the nav panels in the reference,
 * and save the new size to a cookie */
function resizePackagesHeight() {
  var windowHeight = ($(window).height() - HEADER_HEIGHT);
  var swapperHeight = windowHeight - 13; // move 13px for swapper link at the bottom
  resizePackagesNav.css({maxHeight:swapperHeight + "px"});
  classesNav.css({height:swapperHeight - parseInt(resizePackagesNav.css("height")) + "px"});

  $("#swapper").css({height:swapperHeight + "px"});
  $("#packages-nav").css({height:parseInt(resizePackagesNav.css("height")) - 6 + "px"}); //move 6px for handle

  var basePath = getBaseUri(location.pathname);
  var section = basePath.substring(1,basePath.indexOf("/",1));
  writeCookie("height", resizePackagesNav.css("height"), section, null);
}

/* Resize the height of the side-nav and doc-content divs,
 * which creates the frame effect */
function resizeHeight() {
  // Get the window height and always resize the doc-content and side-nav divs
  var windowHeight = ($(window).height() - HEADER_HEIGHT);
  content.css({height:windowHeight + "px"});
  sidenav.css({height:windowHeight + "px"});

  var href = location.href;
  // If in the reference docs, also resize the "swapper", "classes-nav", and "nav-tree"  divs
  if (href.indexOf("/reference/") != -1) {
    var swapperHeight = windowHeight - 13;
    $("#swapper").css({height:swapperHeight + "px"});
    $("#classes-nav").css({height:swapperHeight - parseInt(resizePackagesNav.css("height")) + "px"});
    $("#nav-tree").css({height:swapperHeight + "px"});

  // If in the dev guide docs, also resize the "devdoc-nav" div
  } else if (href.indexOf("/guide/") != -1) {
    $("#devdoc-nav").css({height:sidenav.css("height")});
  }
}

/* Resize the width of the "side-nav" and the left margin of the "doc-content" div,
 * which creates the resizable side bar */
function resizeWidth() {
  var windowWidth = $(window).width() + "px";
  if (sidenav.length) {
    var sidenavWidth = sidenav.css("width");
  } else {
    var sidenavWidth = 0;
  }
  content.css({marginLeft:parseInt(sidenavWidth) + 6 + "px"}); //account for 6px-wide handle-bar

  if (isIE6) {
    content.css({width:parseInt(windowWidth) - parseInt(sidenavWidth) - 6 + "px"}); // necessary in order to for scrollbars to be visible
  }

  resizePackagesNav.css({width:sidenavWidth});
  classesNav.css({width:sidenavWidth});
  $("#packages-nav").css({width:sidenavWidth});

  var basePath = getBaseUri(location.pathname);
  var section = basePath.substring(1,basePath.indexOf("/",1));
  writeCookie("width", sidenavWidth, section, null);
}

/* For IE6 only,
 * because it can't properly perform auto width for "doc-content" div,
 * avoiding this for all browsers provides better performance */
function resizeAll() {
  resizeHeight();
  resizeWidth();
}

function getBaseUri(uri) {
  var intlUrl = (uri.substring(0,6) == "/intl/");
  if (intlUrl) {
    base = uri.substring(uri.indexOf('intl/')+5,uri.length);
    base = base.substring(base.indexOf('/')+1, base.length);
      //alert("intl, returning base url: /" + base);
    return ("/" + base);
  } else {
      //alert("not intl, returning uri as found.");
    return uri;
  }
}

function requestAppendHL(uri) {
//append "?hl=<lang> to an outgoing request (such as to blog)
  var lang = getLangPref();
  if (lang) {
    var q = 'hl=' + lang;
    uri += '?' + q;
    window.location = uri;
    return false;
  } else {
    return true;
  }
}

function loadLast(cookiePath) {
  var location = window.location.href;
  if (location.indexOf("/"+cookiePath+"/") != -1) {
    return true;
  }
  var lastPage = readCookie(cookiePath + "_lastpage");
  if (lastPage) {
    window.location = lastPage;
    return false;
  }
  return true;
}

$(window).unload(function(){
  var path = getBaseUri(location.pathname);
  if (path.indexOf("/reference/") != -1) {
    writeCookie("lastpage", path, "reference", null);
  } else if (path.indexOf("/guide/") != -1) {
    writeCookie("lastpage", path, "guide", null);
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
  var v = readCookie('reference_nav');
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
    init_default_navtree(toRoot);
  }
  var date = new Date();
  date.setTime(date.getTime()+(10*365*24*60*60*1000)); // keep this for 10 years
  writeCookie("nav", nav_pref, "reference", date.toGMTString());

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
    if (selected.is("div")) selected = selected.parent();

    var scrolling = document.getElementById(nav);
    var navHeight = navObj.height();
    var offsetTop = selected.position().top;
    if (selected.parent().parent().is(".toggle-list")) offsetTop += selected.parent().parent().position().top;
    if(offsetTop > navHeight - 92) {
      scrolling.scrollTop = offsetTop - navHeight + 92;
    }
  }
}

function toggleAllInherited(linkObj, expand) {
  var a = $(linkObj);
  var table = $(a.parent().parent().parent());
  var expandos = $(".jd-expando-trigger", table);
  if ( (expand == null && a.text() == "[Expand]") || expand ) {
    expandos.each(function(i) {
      toggleInherited(this, true);
    });
    a.text("[Collapse]");
  } else if ( (expand == null && a.text() == "[Collapse]") || (expand == false) ) {
    expandos.each(function(i) {
      toggleInherited(this, false);
    });
    a.text("[Expand]");
  }
  return false;
}

function toggleAllSummaryInherited(linkObj) {
  var a = $(linkObj);
  var content = $(a.parent().parent().parent());
  var toggles = $(".toggle-all", content);
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


function changeTabLang(lang) {
  var nodes = $("#header-tabs").find("."+lang);
  for (i=0; i < nodes.length; i++) { // for each node in this language 
    var node = $(nodes[i]);
    node.siblings().css("display","none"); // hide all siblings 
    if (node.not(":empty").length != 0) { //if this languages node has a translation, show it 
      node.css("display","inline");
    } else { //otherwise, show English instead 
      node.css("display","none");
      node.siblings().filter(".en").css("display","inline");
    }
  }
}

function changeNavLang(lang) {
  var nodes = $("#side-nav").find("."+lang);
  for (i=0; i < nodes.length; i++) { // for each node in this language 
    var node = $(nodes[i]);
    node.siblings().css("display","none"); // hide all siblings 
    if (node.not(":empty").length != 0) { // if this languages node has a translation, show it 
      node.css("display","inline");
    } else { // otherwise, show English instead 
      node.css("display","none");
      node.siblings().filter(".en").css("display","inline");
    }
  }
}

function changeDocLang(lang) {
  changeTabLang(lang);
  changeNavLang(lang);
}

function changeLangPref(lang, refresh) {
  var date = new Date();
  expires = date.toGMTString(date.setTime(date.getTime()+(10*365*24*60*60*1000))); // keep this for 50 years
  //alert("expires: " + expires)
  writeCookie("pref_lang", lang, null, expires);
  //changeDocLang(lang);
  if (refresh) {
    l = getBaseUri(location.pathname);
    window.location = l;
  }
}

function loadLangPref() {
  var lang = readCookie("pref_lang");
  if (lang != 0) {
    $("#language").find("option[value='"+lang+"']").attr("selected",true);
  }
}

function getLangPref() {
  var lang = $("#language").find(":selected").attr("value");
  if (!lang) {
    lang = readCookie("pref_lang");
  }
  return (lang != 0) ? lang : 'en';
}


function toggleContent(obj) {
  var button = $(obj);
  var div = $(obj.parentNode);
  var toggleMe = $(".toggle-content-toggleme",div);
  if (button.hasClass("show")) {
    toggleMe.slideDown();
    button.removeClass("show").addClass("hide");
  } else {
    toggleMe.slideUp();
    button.removeClass("hide").addClass("show");
  }
  $("span", button).toggle();
}
