/*	
 *	jQuery dacSlideshow 1.0
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
 $.fn.dacSlideshow = function(o) {
     
     //Options - see above
     o = $.extend({
         btnPrev:   null,
         btnNext:   null,
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
         ul.css(sizeCss, ulSize+"px").css(animCss, -(curr*liSize));

         div.css(sizeCss, divSize+"px");
         
         //Pagination
         if (o.pagination) {
             var pagination = $("<div class='pagination'></div>");
             var pag_ul = $("<ul></ul>");
             if (tl > 1) {
               for (var i=0;i<tl;i++) {
                    var li = $("<li>"+i+"</li>");
                    pag_ul.append(li);
                    if (i==o.start) li.addClass('active');
                        li.click(function() {
                        go(parseInt($(this).text()));
                    })
                }
                pagination.append(pag_ul);
                div.append(pagination);
             }
         }
         
         //Previous button
         if(o.btnPrev)
             $(o.btnPrev).click(function(e) {
                 e.preventDefault();
                 return go(curr-o.scroll);
             });

         //Next button
         if(o.btnNext)
             $(o.btnNext).click(function(e) {
                 e.preventDefault();
                 return go(curr+o.scroll);
             });
         
         //Auto rotation
         if(o.auto) startRotateTimer();
             
         function startRotateTimer() {
             clearInterval(timer);
             timer = setInterval(function() {
                  if (curr == tl-1) {
                    go(0);
                  } else {
                    go(curr+o.scroll);  
                  } 
              }, o.autoTime);
         }

         //Go to an item
         function go(to) {
             if(!running) {

                 if(to<0) {
                    to = itemLength-1;
                 } else if (to>itemLength-1) {
                    to = 0;
                 }
                 curr = to;

                 running = true;

                 ul.animate(
                     animCss == "left" ? { left: -(curr*liSize) } : { top: -(curr*liSize) } , o.speed, o.easing,
                     function() {
                         running = false;
                     }
                 );

                 $(o.btnPrev + "," + o.btnNext).removeClass("disabled");
                 $( (curr-o.scroll<0 && o.btnPrev)
                     ||
                    (curr+o.scroll > itemLength && o.btnNext)
                     ||
                    []
                  ).addClass("disabled");

                 
                 var nav_items = $('li', pagination);
                 nav_items.removeClass('active');
                 nav_items.eq(to).addClass('active');
                 

             }
             if(o.auto) startRotateTimer();
             return false;
         };
     });
 };

 function css(el, prop) {
     return parseInt($.css(el[0], prop)) || 0;
 };
 function width(el) {
     return  el[0].offsetWidth + css(el, 'marginLeft') + css(el, 'marginRight');
 };
 function height(el) {
     return el[0].offsetHeight + css(el, 'marginTop') + css(el, 'marginBottom');
 };

 })(jQuery);