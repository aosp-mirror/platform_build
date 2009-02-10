/* file: carousel.js
   date: oct 2008
   author: jeremydw,smain
   info: operates the carousel widget for announcements on 
         the android developers home page. modified from the
         original market.js from jeremydw. */

/* -- video switcher -- */

var oldVid = "multi"; // set the default video
var nowPlayingString = "Now playing:";
var assetsRoot = "/assets/";


/* -- app thumbnail switcher -- */

var currentDroid;
var oldDroid;

// shows a random application
function randomDroid(){

	// count the total number of apps
	var droidListLength = 0;
	for (var k in droidList)
		droidListLength++;
		
	// pick a random app and show it
  var j = 0;
  var i = Math.floor(droidListLength*Math.random());
  for (var x in droidList) {
    if(j++ == i){
    	currentDroid = x;
    	showPreview(x);
    	centerSlide(x);
    }
  }

}

// shows a bulletin, swaps the carousel highlighting
function droid(appName){

  oldDroid = $("#droidlink-"+currentDroid);
  currentDroid = appName;

  var droid = droidList[appName];
  var layout = droid.layout;
  var imgDiv = document.getElementById("bulletinImg");
  var descDiv = document.getElementById("bulletinDesc");

  if (layout == "imgLeft") {
    imgDiv.className = "img-left";
    descDiv.className = "desc-right";
  } else if (layout == "imgTop") {
    imgDiv.className = "img-top";
    descDiv.className = "desc-bottom";
  } else if (layout == "imgRight") {
    imgDiv.className = "img-right";
    descDiv.className = "desc-left";
  }

  imgDiv.innerHTML = "<img src='" + assetsRoot + "images/home/" + droid.img + "'>";
  descDiv.innerHTML = (droid.title != "") ? "<h3>" + droid.title + "</h3>" + droid.desc : droid.desc;

  if(oldDroid)
    oldDroid.removeClass("selected");

  $("#droidlink-"+appName).addClass("selected");
}


// -- * build the carousel based on the droidList * -- //
function buildCarousel() {
  var appList = document.getElementById("app-list");
  for (var x in droidList) {
    var droid = droidList[x];
    var icon = droid.icon;
    var name = droid.name;
    var a = document.createElement("a");
    var img = document.createElement("img");
    var br = document.createElement("br");
    var span = document.createElement("span");
    var text = document.createTextNode(droid.name);

    a.setAttribute("id", "droidlink-" + x);
    a.className = x;
    a.setAttribute("href", "#");
    a.onclick = function() { showPreview(this.className); return false; }
    img.setAttribute("src", assetsRoot + "images/home/" + droid.icon);
    img.setAttribute("alt", "");

    span.appendChild(text);
    a.appendChild(img);
    a.appendChild(br);
    a.appendChild(span);
    appList.appendChild(a);
  }
}

// -- * slider * -- //

// -- dependencies:
//    (1) div containing slides, (2) a "clip" div to hide the scroller
//    (3) control arrows

// -- * config below * -- //

var slideCode = droidList; // the dictionary of slides
var slideList = 'app-list'; // the div containing the slides
var arrowRight = 'arrow-right'; // the right control arrow
var arrowLeft = 'arrow-left'; // the left control arrow


function showPreview(slideName) {
  centerSlide(slideName);
  if (slideName.indexOf('selected') != -1) {
    return false;
  }
  droid(slideName); // do this function when slide is clicked
}

var thumblist = document.getElementById(slideList);// the div containing the slides

var slideWidth = 144; // width of a slide including all margins, etc.
var slidesAtOnce = 3; // no. of slides to appear at once (requires odd number to have a centered slide)

// -- * no editing should be needed below * -- //

var originPosition = {};
var is_animating = 0;
var currentStripPosition = 0;
var centeringPoint = 0;
var rightScrollLimit = 0;

// makeSlideStrip()
// - figures out how many slides there are
// - determines the centering point of the slide strip
function makeSlideStrip() {
  var slideTotal = 0;
  centeringPoint = Math.ceil(slidesAtOnce/2);
  for (var x in slideCode) {
    slideTotal++;
  }
  var i = 0;
  for (var code in slideCode) {
    if (i <= centeringPoint-1) {
      originPosition[code] = 0;
    } else {
      if (i >= slideTotal-centeringPoint+1)  {
        originPosition[code] = (slideTotal-slidesAtOnce)*slideWidth;
      } else {
        originPosition[code] = (i-centeringPoint+1)*slideWidth;
      }
    }
    i++;
  }
  rightScrollLimit = -1*(slideTotal-slidesAtOnce)*slideWidth;
}

// slides with acceleration
function slide(goal, id, go_left, cp) {
  var div = document.getElementById(id);
  var animation = {};
  animation.time = 0.5;  // in seconds
  animation.fps = 60;
  animation.goal = goal;
  origin = 0.0;
  animation.origin = Math.abs(origin);  
  animation.frames = (animation.time * animation.fps) - 1.0;
  var current_frame = 0;
  var motions = Math.abs(animation.goal - animation.origin);
  function animate() {
    var ease_right = function (t) { return (1 - Math.cos(t * Math.PI))/2.0; };
    var ease = ease_right;
    if (go_left == 1) {
      ease = function(t) { return 1.0 - ease_right(t); };
    }
    var left = (ease(current_frame/animation.frames) * Math.abs(animation.goal - animation.origin)) - cp; 
    if(left < 0) {
      left = 0;
    }
    if(!isNaN(left)) {
      div.style.left = '-' + Math.round(left) + 'px';
    }
    current_frame += 1;
    if (current_frame == animation.frames) {
      is_animating = 0;
      window.clearInterval(timeoutId)
    }
  }
  var timeoutId = window.setInterval(animate, animation.time/animation.fps * 1000);
}

//Get style property
function getStyle(element, cssProperty){
  var elem = document.getElementById(element);
  if(elem.currentStyle){
    return elem.currentStyle[cssProperty]; //IE
  } else{
    var style =  document.defaultView.getComputedStyle(elem, null); //firefox, Opera
    return style.getPropertyValue(cssProperty);
  }
}

// Left and right arrows
function page_left() {
  var amount = slideWidth;
  animateSlide(amount, 'left');
}

function page_right() { 
  var amount = slideWidth;
  animateSlide(amount, 'right');
}


// animates the strip
// - sets arrows to on or off
function animateSlide(amount,dir) {
  var currentStripPosition = parseInt(getStyle(slideList,'left'));
  var motionDistance;
  if (amount == slideWidth ) {
    motionDistance = slideWidth;
  } else {
    motionDistance = amount;
  }
  
  var rightarrow = document.getElementById(arrowRight);
  var leftarrow = document.getElementById(arrowLeft);
  
  function aToggle(state,aDir) {
    if (state == 'on') {
      if (aDir =='right') {
        rightarrow.className = 'arrow-right-on';
        rightarrow.href = "javascript:page_right()";
      } else {
        leftarrow.className = 'arrow-left-on';
        leftarrow.href = "javascript:page_left()";
      }
    } else {
      if (aDir =='right') {
        rightarrow.href = "javascript:{}";
        rightarrow.className = 'arrow-right-off'; 
      } else {
        leftarrow.href = "javascript:{}";
        leftarrow.className = 'arrow-left-off';
      }
    }
  }
  
  function arrowChange(rP) {
    if (rP >= rightScrollLimit) {
      aToggle('on','right');
    }
    if (rP <= rightScrollLimit) {
      aToggle('off','right');
    }
    if (rP <= slideWidth) {
      aToggle('on','left');
    }
    if (rP >= 0) {
      aToggle('off','left');
    }
  }

  if (dir == 'right' && is_animating == 0) {
    arrowChange(currentStripPosition-motionDistance);
    is_animating = 1;
    slide(motionDistance, slideList, 0, currentStripPosition);
  } else if (dir == 'left' && is_animating == 0) {
    arrowChange(currentStripPosition+motionDistance);
    is_animating = 1;
    rightStripPosition = currentStripPosition + motionDistance;
    slide(motionDistance, slideList, 1, rightStripPosition);
  }
}

function centerSlide(slideName) {
  var currentStripPosition = parseInt(getStyle(slideList,'left'));
  var dir = 'left';
  var originpoint = Math.abs(currentStripPosition);
  if (originpoint <= originPosition[slideName]) {
    dir = 'right';
  }
  var motionValue = Math.abs(originPosition[slideName]-originpoint);
  animateSlide(motionValue,dir);
}


function initCarousel(def) {
  buildCarousel();
  showPreview(def);
  makeSlideStrip();
}
