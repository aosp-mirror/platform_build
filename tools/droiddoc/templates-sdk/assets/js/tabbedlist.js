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
             if(!running) {
                 curr = to;
                 running = true;

                 frame.animate({ 'margin-left' : -(curr*content_width) }, o.speed, o.easing,
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
     return  el[0].offsetWidth + css(el, 'marginLeft') + css(el, 'marginRight');
 };
 function height(el) {
     return el[0].offsetHeight + css(el, 'marginTop') + css(el, 'marginBottom');
 };

 })(jQuery);