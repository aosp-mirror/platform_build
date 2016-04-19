<?cs
# Other, non-visible things needed at the end of the page,
# because not every page needs footer content, but does need other stuff
?>
</div> <!-- end body-content --> <?cs # normally opened by header.cs ?>

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

<script src="https://developer.android.com/ytblogger_lists_unified.js" defer></script>
<script src="/jd_lists_unified_en.js?v=17" defer></script>
<script src="/reference/lists.js?v=17" defer></script>
<script src="/reference/gcm_lists.js?v=17" defer></script>
<script src="/reference/gms_lists.js?v=17" defer></script>
<script>
  // Load localized metadata.
  (function(lang) {
    if (lang === 'en') { return; }

    // Write it to the document so it gets evaluated before DOMContentReady.
    document.write('<script src="/jd_lists_unified_' + lang + '.js?v=14" defer></' + 'script>');
  })(getLangPref())
</script>
