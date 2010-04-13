<?cs # This file defines custom definitions for the masthead (logo, searchbox, tabs, etc) and 
left nav (toc) that gets placed on all pages, for the open source site?>

<?cs 
def:custom_masthead() ?>
  <div id="header">
      <div id="headerLeft">
          <a href="<?cs var:toroot?>" tabindex="-1"><img
              src="<?cs var:toroot ?>assets/images/open_source.png" alt="Android Open Source Project" /></a>
          <ul class="<?cs if:home ?>home<?cs
                      elif:doc.type == "source" ?>source<?cs
                      elif:doc.type == "porting" ?>porting<?cs
                      elif:doc.type == "compatibility" ?>compatibility<?cs
                      elif:doc.type == "community" ?>community<?cs
                      elif:doc.type == "about" ?>about<?cs /if ?>">
              <li id="home-link"><a href="<?cs var:toroot ?>index.html"><span>Home</span></a></li>
              <li id="source-link"><a href="<?cs var:toroot ?>source/index.html"
                                  onClick="return loadLast('source')"><span>Source</span></a></li>
              <li id="porting-link"><a href="<?cs var:toroot ?>porting/index.html"
                                  onClick="return loadLast('porting')"><span>Porting</span></a></li>
              <li id="compatibility-link"><a href="<?cs var:toroot ?>compatibility/index.html"
                                  onClick="return loadLast('compatibility')"><span>Compatibility</span></a></li>
              <li id="community-link"><a href="<?cs var:toroot ?>community/index.html"
                                  onClick="return loadLast('community')"><span>Community</span></a></li>
              <li id="about-link"><a href="<?cs var:toroot ?>about/index.html"
                                  onClick="return loadLast('about')"><span>About</span></a></li>
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


<?cs def:community_nav() ?>
  <div class="g-section g-tpl-240" id="body-content">
    <div class="g-unit g-first side-nav-resizable" id="side-nav">
      <div id="devdoc-nav"><?cs 
        include:"../../../../development/pdk/docs/community/community_toc.cs" ?>
      </div>
    </div> <!-- end side-nav -->
    <script>
      addLoadEvent(function() {
        scrollIntoView("devdoc-nav");
        });
    </script>
  </div>
<?cs /def ?>

<?cs def:about_nav() ?>
  <div class="g-section g-tpl-240" id="body-content">
    <div class="g-unit g-first side-nav-resizable" id="side-nav">
      <div id="devdoc-nav"><?cs
        include:"../../../../development/pdk/docs/about/about_toc.cs" ?>
      </div>
    </div> <!-- end side-nav -->
    <script>
      addLoadEvent(function() {
        scrollIntoView("devdoc-nav");
        });
    </script>
  </div>
<?cs /def ?>

<?cs def:porting_nav() ?>
  <div class="g-section g-tpl-240" id="body-content">
    <div class="g-unit g-first side-nav-resizable" id="side-nav">
      <div id="devdoc-nav"><?cs
        include:"../../../../development/pdk/docs/porting/porting_toc.cs" ?>
      </div>
    </div> <!-- end side-nav -->
    <script>
      addLoadEvent(function() {
        scrollIntoView("devdoc-nav");
        });
    </script>
  </div>
<?cs /def ?>

<?cs def:source_nav() ?>
  <div class="g-section g-tpl-240" id="body-content">
    <div class="g-unit g-first side-nav-resizable" id="side-nav">
      <div id="devdoc-nav"><?cs
        include:"../../../../development/pdk/docs/source/source_toc.cs" ?>
      </div>
    </div> <!-- end side-nav -->
    <script>
      addLoadEvent(function() {
        scrollIntoView("devdoc-nav");
        });
    </script>
  </div>
<?cs /def ?>

<?cs def:compatibility_nav() ?>
  <div class="g-section g-tpl-240" id="body-content">
    <div class="g-unit g-first side-nav-resizable" id="side-nav">
      <div id="devdoc-nav"><?cs
        include:"../../../../development/pdk/docs/compatibility/compatibility_toc.cs" ?>
      </div>
    </div> <!-- end side-nav -->
    <script>
      addLoadEvent(function() {
        scrollIntoView("devdoc-nav");
        });
    </script>
  </div>
<?cs /def ?>

<?cs def:custom_left_nav() ?>
  <?cs if:doc.hidenav != "true" ?>
    <?cs if:doc.type == "source" ?>
      <?cs call:source_nav() ?>
    <?cs elif:doc.type == "porting" ?>
      <?cs call:porting_nav() ?>
    <?cs elif:doc.type == "compatibility" ?>
      <?cs call:compatibility_nav() ?>
    <?cs elif:doc.type == "community" ?>
      <?cs call:community_nav() ?>
    <?cs elif:doc.type == "about" ?>
      <?cs call:about_nav() ?>
    <?cs /if ?>
  <?cs /if ?>
<?cs /def ?>

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
