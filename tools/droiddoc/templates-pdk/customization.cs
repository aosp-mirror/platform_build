<?cs # This file defines custom definitions for the masthead (logo, searchbox, tabs, etc) and 
left nav (toc) that gets placed on all pages, for the open source site?>

<?cs 
def:custom_masthead() ?>
  <div id="header">
      <div id="headerLeft">
          <a href="http://source.android.com" tabindex="-1"><img
              src="<?cs var:toroot ?>assets/images/open_source.png" alt="Open Source Project: Platform Development Kit" /></a>
          <ul class="<?cs 
                  if:releases ?> releases<?cs
                  elif:guide ?> guide<?cs
                  elif:licenses ?>licenses <?cs
                  elif:home ?>home <?cs
                  elif:community ?>community <?cs /if ?>">
              <li id="home-link"><a href="<?cs var:toroot ?>index.html"><span>Home</span></a></li>
              <li id="guide-link"><a href="<?cs var:toroot ?>guide/index.html"
                                  onClick="return loadLast('guide)'"><span>Guide</span></a></li>
              <li id="releases-ink"><a href="<?cs var:toroot ?>releases/index.html"
                                  onClick="return loadLast('releases)'"><span>Releases</span></a></li>
              <li id="licenses-link"><a href="<?cs var:toroot ?>licenses/index.html"
                                  onClick="return loadLast('licenses)'"><span>Licenses</span></a></li>
              <li id="community-link"><a href="<?cs var:toroot ?>community/index.html"
                                  onClick="return loadLast('community)'"><span>Community</span></a></li>
          </ul> 
      </div>
      <div id="headerRight">
          <div id="headerLinks">
            <!-- <img src="<?cs var:toroot ?>assets/images/icon_world.jpg" alt="" /> -->
            <span class="text">
              <!-- &nbsp;<a href="#">English</a> | -->
              <a href="http://www.android.com">Android.com</a>
            </span>
          </div>
      </div><!-- headerRight -->
  </div><!-- header --><?cs 
/def ?><?cs # custom_masthead ?>


<?cs 
def:guide_nav() ?>
  <div class="g-section g-tpl-240" id="body-content">
    <div class="g-unit g-first side-nav-resizable" id="side-nav">
      <div id="devdoc-nav"><?cs 
        include:"../../../../development/pdk/docs/guide/pdk_toc.cs" ?>
      </div>
    </div> <!-- end side-nav -->
    <script>
      addLoadEvent(function() {
        scrollIntoView("devdoc-nav");
        });
    </script>
<?cs /def ?>

<?cs
def:licenses_nav() ?>
  <div class="g-section g-tpl-240" id="body-content">
    <div class="g-unit g-first side-nav-resizable" id="side-nav">
      <div id="devdoc-nav"><?cs
        include:"../../../../development/pdk/docs/licenses/licenses_toc.cs" ?>
      </div>
    </div> <!-- end side-nav -->
    <script>
      addLoadEvent(function() {
        scrollIntoView("devdoc-nav");
        });
    </script>
<?cs /def ?>

<?cs
def:releases_nav() ?>
  <div class="g-section g-tpl-240" id="body-content">
    <div class="g-unit g-first side-nav-resizable" id="side-nav">
      <div id="devdoc-nav"><?cs
        include:"../../../../development/pdk/docs/releases/releases_toc.cs" ?>
      </div>
    </div> <!-- end side-nav -->
    <script>
      addLoadEvent(function() {
        scrollIntoView("devdoc-nav");
        });
    </script>
<?cs /def ?>

<?cs 
def:custom_left_nav() ?><?cs
  if:doc.type == "guide" ?><?cs
    call:guide_nav() ?><?cs
  elif:doc.type == "licenses" ?><?cs
    call:licenses_nav() ?><?cs
  elif:doc.type == "releases" ?><?cs
    call:releases_nav() ?><?cs
  /if ?><?cs
/def ?>

<?cs # appears at the bottom of every page ?><?cs 
def:custom_cc_copyright() ?>
  Except as noted, this content is 
  licensed under <a href="http://creativecommons.org/licenses/by/2.5/">
  Creative Commons Attribution 2.5</a>. For details and 
  restrictions, see the <a href="http://developer.android.com/license.html">Content 
  License</a>.<?cs 
/def ?>

<?cs 
def:custom_copyright() ?>
  Except as noted, this content is licensed under <a
  href="http://www.apache.org/licenses/LICENSE-2.0">Apache 2.0</a>. 
  For details and restrictions, see the <a href="http://developer.android.com/license.html">
  Content License</a>.<?cs 
/def ?>

<?cs 
def:custom_footerlinks() ?>
  <p>
    <a href="http://www.android.com/terms.html">Site Terms of Service</a> -
    <a href="http://www.android.com/privacy.html">Privacy Policy</a> -
    <a href="http://www.android.com/branding.html">Brand Guidelines</a>
  </p><?cs 
/def ?>

<?cs # appears on the right side of the blue bar at the bottom off every page ?><?cs 
def:custom_buildinfo() ?>
  Android <?cs var:sdk.platform.version ?>&nbsp;r<?cs var:sdk.rel.id ?> - <?cs var:page.now ?>
<?cs /def ?>
