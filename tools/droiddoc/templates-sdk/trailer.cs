</div> <!-- end body-content --> <?cs # normally opened by header.cs ?>




<!-- Grid - for dev 
<script type="text/javascript">

window.gOverride = {
		gColor: '#FF0000',
		pColor: '#EEEEEE',
		gOpacity: 0.10,
		pOpacity: 0.40,
		pHeight: 16,
		pOffset: 2,
		gColumns:16,
		gEnabled:false,
		pEnabled:false
	}
</script>
	
<link href="<?cs var:toroot ?>assets/js/grid/960.gridder.css" rel="stylesheet" type="text/css">
<script src="<?cs var:toroot ?>assets/js/grid/960.gridder.js" type="text/javascript"></script>
-->



<?cs if:carousel ?>
<script type="text/javascript">
$('.slideshow-container').dacSlideshow({
    btnPrev: '.slideshow-prev',
    btnNext: '.slideshow-next',
    btnPause: '#pauseButton'
});
</script>
<?cs /if ?>
<?cs if:tabbedList ?>
<script type="text/javascript">
$(".feed").dacTabbedList({
    nav_id: '.feed-nav',
    frame_id: '.feed-frame'
});
</script>
<?cs /if ?>
<script type="text/javascript">
init(); /* initialize android-developer-docs.js */
</script>

