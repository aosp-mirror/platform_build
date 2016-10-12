<?cs 
def:sdk_nav() ?>
  <div class="g-section g-tpl-240" id="body-content">
    <div class="g-unit g-first" id="side-nav" itemscope itemtype="http://schema.org/SiteNavigationElement">
      <div id="devdoc-nav"><?cs 
        include:"../../../../../frameworks/base/docs/html/sdk/sdk_toc.cs" ?>
      </div>
    </div> <!-- end side-nav -->
<?cs /def ?>
<?cs 
def:resources_tab_nav() ?>
  <div class="g-section g-tpl-240" id="body-content">
    <div class="g-unit g-first" id="side-nav" itemscope itemtype="http://schema.org/SiteNavigationElement">
      <div id="devdoc-nav"><?cs 
        include:"../../../../../frameworks/base/docs/html/resources/resources_toc.cs" ?>
      </div>
    </div> <!-- end side-nav -->
    <script>
      addLoadEvent(function() {
        scrollIntoView("devdoc-nav");
        });
    </script>
<?cs /def ?>
<?cs 
def:guide_nav() ?>
  <div class="g-section g-tpl-240" id="body-content">
    <div class="g-unit g-first" id="side-nav" itemscope itemtype="http://schema.org/SiteNavigationElement">
      <div id="devdoc-nav"><?cs 
        include:"../../../../../vendor/pdk/data/google/docs/guide/guide_toc.cs" ?>
      </div>
    </div> <!-- end side-nav -->
    <script>
      addLoadEvent(function() {
        scrollIntoView("devdoc-nav");
        });
    </script>
<?cs /def ?>
<?cs
def:design_nav() ?>
  <?cs include:"../../../../../frameworks/base/docs/html/design/design_toc.cs" ?>
<?cs /def ?>

<?cs # The default side navigation for the reference docs ?><?cs 
def:default_left_nav() ?>
  <div class="g-section g-tpl-240" id="body-content">
    <div class="g-unit g-first" id="side-nav" itemscope itemtype="http://schema.org/SiteNavigationElement">
      <div id="swapper">
        <div id="nav-panels">
          <div id="resize-packages-nav">
            <div id="packages-nav">
              <div id="index-links"><nobr>
                <a href="<?cs var:toroot ?>reference/packages.html" <?cs if:(page.title == "Package Index") ?>class="selected"<?cs /if ?> >Package Index</a> | 
                <a href="<?cs var:toroot ?>reference/classes.html" <?cs if:(page.title == "Class Index") ?>class="selected"<?cs /if ?>>Class Index</a></nobr>
              </div>
              <ul>
              	<?cs call:package_link_list(docs.packages) ?>
              </ul><br/>
            </div> <!-- end packages -->
          </div> <!-- end resize-packages -->
          <div id="classes-nav"><?cs 
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
              <script>
                /*addLoadEvent(maxPackageHeight);*/
              </script>
              <p style="padding:10px">Select a package to view its members</p><?cs 
            /if ?><br/>
          </div><!-- end classes -->
        </div><!-- end nav-panels -->
        <div id="nav-tree" style="display:none">
          <div id="index-links"><nobr>
            <a href="<?cs var:toroot ?>reference/packages.html" <?cs if:(page.title == "Package Index") ?>class="selected"<?cs /if ?> >Package Index</a> | 
            <a href="<?cs var:toroot ?>reference/classes.html" <?cs if:(page.title == "Class Index") ?>class="selected"<?cs /if ?>>Class Index</a></nobr>
          </div>
        </div><!-- end nav-tree -->
      </div><!-- end swapper -->
    </div> <!-- end side-nav -->
    <script>
      if (!isMobile) {
        $("<a href='#' id='nav-swap' onclick='swapNav();return false;' style='font-size:10px;line-height:9px;margin-left:1em;text-decoration:none;'><span id='tree-link'>Use Tree Navigation</span><span id='panel-link' style='display:none'>Use Panel Navigation</span></a>").appendTo("#side-nav");
        chooseDefaultNav();
        if ($("#nav-tree").is(':visible')) {
          init_default_navtree("<?cs var:toroot ?>");
        } else {
          addLoadEvent(function() {
            scrollIntoView("packages-nav");
            scrollIntoView("classes-nav");
          });
        }
        $("#swapper").css({borderBottom:"2px solid #aaa"});
      } else {
        swapNav(); // tree view should be used on mobile
      }
    </script><?cs 
/def ?>

<?cs 
def:custom_left_nav() ?><?cs 
  if:guide ?><?cs 
    call:guide_nav() ?><?cs 
  elif:resources ?><?cs 
    call:resources_tab_nav() ?><?cs 
  elif:sdk ?><?cs 
    call:sdk_nav() ?><?cs 
  else ?><?cs 
    call:default_left_nav() ?><?cs 
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
    <a href="http://www.google.com/intl/en/policies/" target="_blank">Privacy &amp; Terms</a> -
    <a href="http://www.android.com/branding.html" target="_blank">Brand Guidelines</a> -
    <a
href="http://code.google.com/p/android/issues/entry?template=Developer%20Documentation"
target="_blank">Report Document Issues</a>
  </p><?cs 
/def ?>

<?cs # appears on the right side of the blue bar at the bottom off every page ?><?cs 
def:custom_buildinfo() ?>
  Android <?cs var:sdk.version ?>&nbsp;r<?cs var:sdk.rel.id ?> - <?cs var:page.now ?>
<?cs /def ?>