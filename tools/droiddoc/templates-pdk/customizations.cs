<?cs # This file defines custom definitions for the masthead (logo, searchbox, tabs, etc) and 
left nav (toc) that gets placed on all pages, for the open source site. See also the components/
directory. ?>
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
<?cs def:custom_cc_copyright() ?>
<?cs /def ?>

<?cs def:custom_copyright() ?>
<?cs /def ?>

<?cs 
def:custom_footerlinks() ?>
  <p>
    <a href="http://www.android.com/terms.html">Site Terms of Service</a> -
    <a href="http://www.android.com/privacy.html">Privacy Policy</a>
  </p><?cs 
/def ?>

<?cs # appears on the right side of the blue bar at the bottom off every page ?>
<?cs def:custom_buildinfo() ?>
<?cs /def ?>
