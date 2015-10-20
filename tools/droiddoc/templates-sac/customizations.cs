<?cs 
def:fullpage() ?>
  <div id="body-content">
<?cs /def ?>
<?cs 
def:sdk_nav() ?>
  <div class="wrap clearfix" id="body-content">
    <div class="col-4" id="side-nav" itemscope itemtype="http://schema.org/SiteNavigationElement">
      <div id="devdoc-nav" class="scroll-pane">
<a class="totop" href="#top" data-g-event="left-nav-top">to top</a>

<?cs 
        include:"../../../../frameworks/base/docs/html/sdk/sdk_toc.cs" ?>


      </div>
    </div> <!-- end side-nav -->
<?cs /def ?>
<?cs 
def:resources_tab_nav() ?>
  <div class="wrap clearfix" id="body-content">
    <a
    <div class="col-4" id="side-nav" itemscope itemtype="http://schema.org/SiteNavigationElement">
      <div id="devdoc-nav" class="scroll-pane">
<a class="totop" href="#top" data-g-event="left-nav-top">to top</a>

<?cs 
        include:"../../../../frameworks/base/docs/html/resources/resources_toc.cs" ?>


      </div>
    </div> <!-- end side-nav -->
    <script>
      $(document).ready(function() {
        scrollIntoView("devdoc-nav");
        });
    </script>
<?cs /def ?>
<?cs
def:tools_nav() ?>
  <div class="wrap clearfix" id="body-content">
    <div class="col-3" id="side-nav" itemscope itemtype="http://schema.org/SiteNavigationElement">
      <div id="devdoc-nav" class="scroll-pane">
<a class="totop" href="#top" data-g-event="left-nav-top">to top</a>
<?cs 
        include:"../../../../frameworks/base/docs/html/tools/tools_toc.cs" ?>
        
        
      </div>
    </div> <!-- end side-nav -->
    <script>
      $(document).ready(function() {
        scrollIntoView("devdoc-nav");
        });
    </script>
<?cs /def ?>
<?cs
def:training_nav() ?>
  <div class="wrap clearfix" id="body-content">
    <div class="col-4" id="side-nav" itemscope itemtype="http://schema.org/SiteNavigationElement">
      <div id="devdoc-nav" class="scroll-pane">
<a class="totop" href="#top" data-g-event="left-nav-top">to top</a>


<?cs 
        include:"../../../../frameworks/base/docs/html/training/training_toc.cs" ?>
        

      </div>
    </div> <!-- end side-nav -->
    <script>
      $(document).ready(function() {
        scrollIntoView("devdoc-nav");
        });
    </script>
<?cs /def ?>
<?cs 
def:guide_nav() ?>
  <div class="wrap clearfix" id="body-content">
    <div class="col-4" id="side-nav" itemscope itemtype="http://schema.org/SiteNavigationElement">
      <div id="devdoc-nav" class="scroll-pane">
<a class="totop" href="#top" data-g-event="left-nav-top">to top</a>


<?cs 
        include:"../../../../frameworks/base/docs/html/guide/guide_toc.cs" ?>
        

      </div>
    </div> <!-- end side-nav -->
    <script>
      $(document).ready(function() {
        scrollIntoView("devdoc-nav");
        });
    </script>
<?cs /def ?>
<?cs
def:design_nav() ?>
  <div class="wrap clearfix" id="body-content">
    <div class="col-3" id="side-nav" itemscope itemtype="http://schema.org/SiteNavigationElement">
      <div id="devdoc-nav" class="scroll-pane">
<a class="totop" href="#top" data-g-event="left-nav-top">to top</a>


<?cs
        include:"../../../../frameworks/base/docs/html/design/design_toc.cs" ?>
       

      </div>
    </div> <!-- end side-nav -->
    <script>
      $(document).ready(function() {
        scrollIntoView("devdoc-nav");
        });
    </script>
<?cs /def ?>
<?cs
def:distribute_nav() ?>
  <div class="wrap clearfix" id="body-content">
    <div class="col-3" id="side-nav" itemscope itemtype="http://schema.org/SiteNavigationElement">
      <div id="devdoc-nav" class="scroll-pane">
<a class="totop" href="#top" data-g-event="left-nav-top">to top</a>

<?cs
        include:"../../../../frameworks/base/docs/html/distribute/distribute_toc.cs" ?>
        

      </div>
    </div> <!-- end side-nav -->
    <script>
      $(document).ready(function() {
        scrollIntoView("devdoc-nav");
        });
    </script>
<?cs /def ?>

<?cs
def:google_nav() ?>
  <div class="wrap clearfix" id="body-content">
    <div class="col-4" id="side-nav" itemscope itemtype="http://schema.org/SiteNavigationElement">
      <div id="devdoc-nav" class="scroll-pane">
<a class="totop" href="#top" data-g-event="left-nav-top">to top</a>

<?cs
        include:"../../../../frameworks/base/docs/html/google/google_toc.cs" ?>
        

      </div>
      <script type="text/javascript">
       showGoogleRefTree();
    
      </script>
    </div> <!-- end side-nav -->
    <script>
      $(document).ready(function() {
        scrollIntoView("devdoc-nav");
        });
    </script>
<?cs /def ?>

<?cs
def:about_nav() ?>
  <div class="wrap clearfix" id="body-content">
    <div class="col-3" id="side-nav" itemscope itemtype="http://schema.org/SiteNavigationElement">
      <div id="devdoc-nav" class="scroll-pane">
<a class="totop" href="#top" data-g-event="left-nav-top">to top</a>

<?cs
        include:"../../../../frameworks/base/docs/html/about/about_toc.cs" ?>
        

      </div>
    </div> <!-- end side-nav -->
    <script>
      $(document).ready(function() {
        scrollIntoView("devdoc-nav");
        });
    </script>
<?cs /def ?>
<?cs
def:dist_more_nav() ?>
  <div class="wrap clearfix" id="body-content">
    <div class="col-4" id="side-nav" itemscope itemtype="http://schema.org/SiteNavigationElement">
      <div id="devdoc-nav" class="scroll-pane">
<a class="totop" href="#top" data-g-event="left-nav-top">to top</a>


<?cs 
        include:"../../../../frameworks/base/docs/html/distribute/more/more_toc.cs" ?>
        

      </div>
    </div> <!-- end side-nav -->
    <script>
      $(document).ready(function() {
        scrollIntoView("devdoc-nav");
        });
    </script>
:

<?cs /def ?>

<?cs # The default side navigation for the reference docs ?><?cs 
def:default_left_nav() ?>
<?cs if:reference.gcm || reference.gms ?>
  <?cs call:google_nav() ?>
<?cs else ?>
  <div class="wrap clearfix" id="body-content">
    <div class="col-4" id="side-nav" itemscope itemtype="http://schema.org/SiteNavigationElement">
      <div id="devdoc-nav">

<a class="totop" href="#top" data-g-event="left-nav-top">to top</a>
      <div id="api-nav-header">
        <div id="api-level-toggle">
          <label for="apiLevelCheckbox" class="disabled">API level: </label>
          <div class="select-wrapper">
            <select id="apiLevelSelector">
              <!-- option elements added by buildApiLevelSelector() -->
            </select>
          </div>
        </div><!-- end toggle -->
        <div id="api-nav-title">Android APIs</div>
        </div><!-- end nav header -->
      <script>
        var SINCE_DATA = [ <?cs 
          each:since = since ?>'<?cs 
            var:since.name ?>'<?cs 
            if:!last(since) ?>, <?cs /if ?><?cs
          /each 
        ?> ];
        buildApiLevelSelector();
      </script>
                  
      <div id="swapper">
        <div id="nav-panels">
          <div id="resize-packages-nav">
            <div id="packages-nav" class="scroll-pane">

              <ul>
              	<?cs call:package_link_list(docs.packages) ?>
              </ul><br/>

            </div> <!-- end packages-nav -->
          </div> <!-- end resize-packages -->
          <div id="classes-nav" class="scroll-pane">


<?cs 
            if:subcount(class.package) ?>
            <ul>
              <?cs call:list("Interfaces", class.package.interfaces) ?>
              <?cs call:list("Classes", class.package.classes) ?>
              <?cs call:list("Enums", class.package.enums) ?>
              <?cs call:list("Exceptions", class.package.exceptions) ?>
              <?cs call:list("Errors", class.package.errors) ?>
            </ul><?cs 
            elif:subcount(package) ?>
            <ul>
              <?cs call:class_link_list("Interfaces", package.interfaces) ?>
              <?cs call:class_link_list("Classes", package.classes) ?>
              <?cs call:class_link_list("Enums", package.enums) ?>
              <?cs call:class_link_list("Exceptions", package.exceptions) ?>
              <?cs call:class_link_list("Errors", package.errors) ?>
            </ul><?cs 
            else ?>
              <p style="padding:10px">Select a package to view its members</p><?cs 
            /if ?><br/>
        

          </div><!-- end classes -->
        </div><!-- end nav-panels -->
        <div id="nav-tree" style="display:none" class="scroll-pane">
          <div id="tree-list"></div>
        </div><!-- end nav-tree -->
      </div><!-- end swapper -->
      <div id="nav-swap">
      <a class="fullscreen">fullscreen</a>
      <a href='#' onclick='swapNav();return false;'><span id='tree-link'>Use Tree Navigation</span><span id='panel-link' style='display:none'>Use Panel Navigation</span></a>
      </div>
    </div> <!-- end devdoc-nav -->
    </div> <!-- end side-nav -->
    <script type="text/javascript">
      // init fullscreen based on user pref
      var fullscreen = readCookie("fullscreen");
      if (fullscreen != 0) {
        if (fullscreen == "false") {
          toggleFullscreen(false);
        } else {
          toggleFullscreen(true);
        }
      }
      // init nav version for mobile
      if (isMobile) {
        swapNav(); // tree view should be used on mobile
        $('#nav-swap').hide();
      } else {
        chooseDefaultNav();
        if ($("#nav-tree").is(':visible')) {
          init_default_navtree("<?cs var:toroot ?>");
        }
      }
      // scroll the selected page into view
      $(document).ready(function() {
        scrollIntoView("packages-nav");
        scrollIntoView("classes-nav");
        });
    </script>
<?cs /if ?>
    <?cs 
/def ?>

<?cs 
def:custom_left_nav() ?><?cs
  if:fullpage ?><?cs 
    call:fullpage() ?><?cs 
  elif:guide ?><?cs 
    call:guide_nav() ?><?cs 
  elif:design ?><?cs
    call:design_nav() ?><?cs 
  elif:training ?><?cs 
    call:training_nav() ?><?cs 
  elif:tools ?><?cs 
    call:tools_nav() ?><?cs
  elif:google ?><?cs 
    call:google_nav() ?><?cs 
  elif:more ?><?cs 
    call:dist_more_nav() ?><?cs
  elif:distribute ?><?cs 
    call:distribute_nav() ?><?cs 
  elif:about ?><?cs 
    call:about_nav() ?><?cs 
  else ?><?cs 
    call:default_left_nav() ?> <?cs 
  /if ?><?cs 
/def ?>

<?cs # appears at the bottom of every page ?><?cs 
def:custom_cc_copyright() ?>
  Except as noted, this content is 
  licensed under <a href="http://creativecommons.org/licenses/by/2.5/">
  Creative Commons Attribution 2.5</a>. For details and 
  restrictions, see the <a href="<?cs var:toroot ?>license.html">Content 
  License</a>.<?cs 
/def ?>

<?cs 
def:custom_copyright() ?>
  Except as noted, this content is licensed under <a
  href="http://www.apache.org/licenses/LICENSE-2.0">Apache 2.0</a>. 
  For details and restrictions, see the <a href="<?cs var:toroot ?>license.html">
  Content License</a>.<?cs 
/def ?>

<?cs 
def:custom_footerlinks() ?>
  <p>
    <a href="<?cs var:toroot ?>source/index.html">About Android</a>&nbsp;&nbsp;|&nbsp;
    <a href="<?cs var:toroot ?>source/community.html">Community</a>&nbsp;&nbsp;|&nbsp;
    <a href="<?cs var:toroot ?>legal.html">Legal</a>&nbsp;&nbsp;|&nbsp;
  </p><?cs 
/def ?>

<?cs # appears on the right side of the blue bar at the bottom off every page ?><?cs 

def:custom_buildinfo() ?><?cs
  if:!google && !reference.gms && !reference.gcm?>
    Android <?cs var:sdk.version ?>&nbsp;r<?cs var:sdk.rel.id ?> &mdash; <?cs
  /if ?>
<script src="<?cs var:toroot ?>timestamp.js" type="text/javascript"></script>
<script>document.write(BUILD_TIMESTAMP)</script>
<?cs /def ?>



<?cs #------------------- s.a.c specific templating ---------------------------?>

<?cs 
def:sac_left_nav() ?>
  <?cs if:devices ?>
    <?cs call:devices_nav() ?>
  <?cs elif:compatibility ?>
    <?cs call:compatibility_nav() ?>
  <?cs elif:source ?>
    <?cs call:source_nav() ?>
  <?cs elif:security ?>
    <?cs call:security_nav() ?>
  <?cs elif:reference ?>
    <?cs call:default_left_nav() ?>
  <?cs /if ?>
<?cs /def ?>

<?cs
def:devices_nav() ?>
  <div class="wrap clearfix" id="body-content">
    <div class="col-4" id="side-nav" itemscope itemtype="http://schema.org/SiteNavigationElement">
      <div id="devdoc-nav" class="scroll-pane">
<a class="totop" href="#top" data-g-event="left-nav-top">to top</a>

<?cs 
        include:"../../../../docs/source.android.com/src/devices/devices_toc.cs" ?>

      </div>
      <script type="text/javascript">
        showTradefedRefTree();
      </script>
    </div> <!-- end side-nav -->
    <script>
      $(document).ready(function() {
        scrollIntoView("devdoc-nav");
        });
    </script>
<?cs /def ?>

<?cs
def:compatibility_nav() ?>
  <div class="wrap clearfix" id="body-content">
    <div class="col-4" id="side-nav" itemscope itemtype="http://schema.org/SiteNavigationElement">
      <div id="devdoc-nav" class="scroll-pane">
<a class="totop" href="#top" data-g-event="left-nav-top">to top</a>

<?cs 
        include:"../../../../docs/source.android.com/src/compatibility/compatibility_toc.cs" ?>

      </div>
    </div> <!-- end side-nav -->
    <script>
      $(document).ready(function() {
        scrollIntoView("devdoc-nav");
        });
    </script>
<?cs /def ?>

<?cs
def:source_nav() ?>
  <div class="wrap clearfix" id="body-content">
    <div class="col-4" id="side-nav" itemscope itemtype="http://schema.org/SiteNavigationElement">
      <div id="devdoc-nav" class="scroll-pane">
<a class="totop" href="#top" data-g-event="left-nav-top">to top</a>

<?cs 
        include:"../../../../docs/source.android.com/src/source/source_toc.cs" ?>

      </div>
    </div> <!-- end side-nav -->
    <script>
      $(document).ready(function() {
        scrollIntoView("devdoc-nav");
        });
    </script>
<?cs /def ?>

<?cs
def:security_nav() ?>
  <div class="wrap clearfix" id="body-content">
    <div class="col-4" id="side-nav" itemscope itemtype="http://schema.org/SiteNavigationElement">
      <div id="devdoc-nav" class="scroll-pane">
<a class="totop" href="#top" data-g-event="left-nav-top">to top</a>

<?cs 
        include:"../../../../docs/source.android.com/src/security/security_toc.cs" ?>

      </div>
    </div> <!-- end side-nav -->
    <script>
      $(document).ready(function() {
        scrollIntoView("devdoc-nav");
        });
    </script>
<?cs /def ?>


