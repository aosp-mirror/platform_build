<?cs # This default template file is meant to be replaced. ?>
<?cs # Use the -tempatedir arg to javadoc to set your own directory with a replacement for this file in it. ?>

<?cs def:custom_masthead() ?>
<div id="header">
    <div id="headerLeft">
        <a href="<?cs var:toroot ?>index.html" tabindex="-1"><img
            src="<?cs var:toroot ?>assets/images/bg_logo.jpg" /></a>
    </div>
    <div id="headerRight">
        <div id="headerLinks" align="right">
            <img src="<?cs var:toroot ?>assets/images/icon_world.jpg"><span class="text">&nbsp;<a href="#">English</a> | <a href="http://www.android.com">Android.com</a></span>
        </div>

        <?cs call:default_search_box() ?>
        <ul class="<?cs 
                if:reference ?>reference<?cs
                elif:guide ?>guide<?cs
                elif:sdk ?>sdk<?cs
                elif:home ?>home<?cs
                elif:community ?>community<?cs
                elif:publish ?>publish<?cs
                elif:about ?>about<?cs /if ?>">		
            <?cs if:android.whichdoc == "online" ?>
            <li id="home-link"><a href="<?cs var:toroot ?>index.html"><span>Home</span></a></li>
            <?cs /if ?>
            <li id="sdk-link"><a href="<?cs var:toroot ?>sdk/index.html"><span>SDK</span></a></li>
            <li id="guide-link"><a href="<?cs var:toroot ?>guide/index.html"
                                onClick="return loadLast('guide')"><span>Dev Guide</span></a></li>
            <li id="reference-link"><a href="<?cs var:toroot ?>reference/packages.html" 
                                onClick="return loadLast('reference')"><span>Reference</span></a></li>
            <li><a href="http://android-developers.blogspot.com"><span>Blog</span></a></li>
            <li id="community-link"><a href="<?cs var:toroot ?>community/index.html"><span>Community</span></a></li>
        </ul>

    </div><!-- headerRight -->
</div><!-- header -->

<?cs /def ?><?cs # custom_masthead ?>

<?cs def:sdk_nav() ?>
<div class="g-section g-tpl-180" id="body-content">
  <div class="g-unit g-first" id="side-nav">
    <div id="devdoc-nav">
      <?cs include:"../../../java/android/html/sdk/sdk_toc.cs" ?>
    </div>
  </div> <!-- end side-nav -->
<?cs /def ?>

<?cs def:guide_nav() ?>
<div class="g-section g-tpl-240" id="body-content">
  <div class="g-unit g-first side-nav-resizable" id="side-nav">
    <div id="devdoc-nav">
      <?cs include:"../../../java/android/html/guide/guide_toc.cs" ?>
    </div>
  </div> <!-- end side-nav -->
  <script>
    addLoadEvent(function() {
      scrollIntoView("devdoc-nav");
      });
  </script>
<?cs /def ?>

<?cs def:publish_nav() ?>
<div class="g-section g-tpl-180" id="body-content">
  <div class="g-unit g-first" id="side-nav">
    <div id="devdoc-nav">
      <?cs include:"../../../java/android/html/publish/publish_toc.cs" ?>
    </div>
  </div> <!-- end side-nav -->
<?cs /def ?>

<?cs def:custom_left_nav() ?>
  <?cs if:guide ?>
    <?cs call:guide_nav() ?>
  <?cs elif:publish ?>
    <?cs call:publish_nav() ?> 
  <?cs elif:sdk ?>
    <?cs call:sdk_nav() ?>
  <?cs else ?>
    <?cs call:default_left_nav() ?> 
  <?cs /if ?>
<?cs /def ?>


<?cs # appears on the left side of the blue bar at the bottom of every page ?>
<?cs def:custom_copyright() ?>Copyright 2008 <a href="http://source.android.com/">The Android Open Source Project</a><?cs /def ?>

<?cs # appears on the right side of the blue bar at the bottom of every page ?>
<?cs def:custom_buildinfo() ?>Build <?cs var:page.build ?> - <?cs var:page.now ?><?cs /def ?>
