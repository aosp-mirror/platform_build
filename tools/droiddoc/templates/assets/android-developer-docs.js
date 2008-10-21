var resizePackagesNav;
var classesNav;
var devdocNav;
var sidenav;
var content;
var HEADER_HEIGHT = 103;
var cookie_style = 'android_dev_docs';

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
  sidenav.css({height:windowHeight + "px"});
  content.css({height:windowHeight + "px"});
  resizePackagesNav.css({maxHeight:windowHeight + "px", height:packageHeight});
  classesNav.css({height:windowHeight - parseInt(packageHeight) + "px"});
  $("#packages-nav").css({height:parseInt(packageHeight) - 6 + "px"}); //move 6px to give space for the resize handle
  devdocNav.css({height:sidenav.css("height")});
}

function getCookie(cookie) {
  var myCookie = cookie_style+"_"+cookie+"=";
  if (document.cookie) {
    var index = document.cookie.indexOf(myCookie);
    if (index != -1) {
      var valStart = index + myCookie.length;
      var valEnd = document.cookie.indexOf(";", valStart);
      var val = document.cookie.substring(valStart, valEnd);
      return val;
    }
  }
  return 0;
}

function writeCookie(cookie, val) {
  if (location.href.indexOf("reference") != -1) {
    document.cookie = cookie_style+'_'+cookie+'='+val+'; path=/gae/reference';
  }
} 

function prepare() {
  $("#side-nav").css({position:"absolute",left:0});
  content = $("#doc-content");
  resizePackagesNav = $("#resize-packages-nav");
  classesNav = $("#classes-nav");
  sidenav = $("#side-nav");
  devdocNav = $("#devdoc-nav");

  var cookieWidth = getCookie('width');
  var cookieHeight = getCookie('height');
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
  if (lastSlashPos == (fullPageName.length - 1)) { // if the url ends in slash (index.html)
    fullPageName = fullPageName + "index.html";
  }
  var htmlPos = fullPageName.lastIndexOf(".html", fullPageName.length);
  var pageName = fullPageName.slice(firstSlashPos, htmlPos + 5);
  var link = $("#devdoc-nav a[href$='"+pageName+"']");
  if (link.length == 0) { // if there's no match, maybe the nav url ends in a slash, also
    link = $("#devdoc-nav a[href$='"+pageName.slice(0,pageName.indexOf("index.html"))+"']");
  }
  link.parent().addClass('selected');
}

function resizeHeight() {
  var windowHeight = ($(window).height() - HEADER_HEIGHT);
  sidenav.css({height:windowHeight + "px"});
  content.css({height:windowHeight + "px"});
  resizePackagesNav.css({maxHeight:windowHeight + "px"});
  classesNav.css({height:windowHeight - parseInt(resizePackagesNav.css("height")) + "px"});
  $("#packages-nav").css({height:parseInt(resizePackagesNav.css("height")) - 6 + "px"}); //move 6px for handle
  devdocNav.css({height:sidenav.css("height")});
  writeCookie("height", resizePackagesNav.css("height"));
}

function resizeWidth() {
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
  writeCookie("width", sidenavWidth);
}

function resizeAll() {
  resizeHeight();
  resizeWidth();
}

//added to onload when the bottom-left panel is empty
function maxPackageHeight() { 
  var windowHeight = resizePackagesNav.css("maxHeight");
  resizePackagesNav.css({height:windowHeight}); 
  $("#packages-nav").css({height:windowHeight}); 
}

$(document).ready(function(){
  $("#resize-packages-nav").resizable({handles: "s", resize: function(e, ui) { resizeHeight(); } });
  $(".side-nav-resizable").resizable({handles: "e", resize: function(e, ui) { resizeWidth(); } });
});