<?cs # This default template file is meant to be replaced. ?>
<?cs # Use the -tempatedir arg to javadoc to set your own directory with a replacement for this file in it. ?>


<?cs # The default search box that goes in the header ?><?cs 
def:default_search_box() ?>
  <div id="search" >
      <div id="searchForm">
          <form accept-charset="utf-8" class="gsc-search-box" 
                onsubmit="return submit_search()">
            <table class="gsc-search-box" cellpadding="0" cellspacing="0"><tbody>
                <tr>
                  <td class="gsc-input">
                    <input id="search_autocomplete" class="gsc-input" type="text" size="33" autocomplete="off"
                      title="search developer docs" name="q"
                      value="search developer docs"
                      onFocus="search_focus_changed(this, true)"
                      onBlur="search_focus_changed(this, false)"
                      onkeydown="return search_changed(event, true, '<?cs var:toroot?>')"
                      onkeyup="return search_changed(event, false, '<?cs var:toroot?>')" />
                  <div id="search_filtered_div" class="no-display">
                      <table id="search_filtered" cellspacing=0>
                      </table>
                  </div>
                  </td>
                  <td class="gsc-search-button">
                    <input type="submit" value="Search" title="search" id="search-button" class="gsc-search-button" />
                  </td>
                  <td class="gsc-clear-button">
                    <div title="clear results" class="gsc-clear-button">&nbsp;</div>
                  </td>
                </tr></tbody>
              </table>
          </form>
      </div><!-- searchForm -->
  </div><!-- search --><?cs 
/def ?>

<?cs 
def:custom_masthead() ?>
  <div id="header">
      <div id="headerLeft">
          <a href="<?cs var:toroot ?>index.html" tabindex="-1"><img
              src="<?cs var:toroot ?>assets/images/bg_logo.png" alt="Android Developers" /></a>
          <?cs include:"header_tabs.cs" ?>     <?cs # The links are extracted so we can better manage localization ?>
      </div>
      <div id="headerRight">
          <div id="headerLinks">
          <?cs if:template.showLanguageMenu ?>
            <img src="<?cs var:toroot ?>assets/images/icon_world.jpg" alt="Language:" /> 
            <span id="language">
             	<select name="language" onChange="changeLangPref(this.value, true)">
          			<option value="en">English&nbsp;&nbsp;&nbsp;</option>
          			<option value="ja">日本語</option>
          			<?cs # 
      			    <option value="de">Deutsch</option> 
          			<option value="es">Español</option>
          			<option value="fr">Français</option>
          			<option value="it">Italiano</option>
          			<option value="zh-CN">中文 (简体)</option>
          			<option value="zh-TW">中文 (繁體)</option>
      			    ?>
             	</select>	
             	<script type="text/javascript">
             	  <!--  
                  loadLangPref();  
             	   //-->
             	</script>
            </span>
          <?cs /if ?>
          <a href="http://www.android.com">Android.com</a>
          </div><?cs 
          call:default_search_box() ?><?cs 
    	 	  if:reference ?>
    			  <div id="api-level-toggle">
    			    <input type="checkbox" id="apiLevelCheckbox" onclick="toggleApiLevelSelector(this)" />
    			    <label for="apiLevelCheckbox" class="disabled">Filter by API Level: </label>
    			    <select id="apiLevelSelector">
    			      <!-- option elements added by buildApiLevelSelector() -->
    			    </select>
    			  </div>
    	 	    <script>
              var SINCE_DATA = [ <?cs 
                each:since = since ?>'<?cs 
                  var:since.name ?>'<?cs 
                  if:!last(since) ?>, <?cs /if ?><?cs
                /each 
              ?> ];
              buildApiLevelSelector();
            </script><?cs 
    			/if ?>
      </div><!-- headerRight -->
      <script type="text/javascript">
        <!--  
        changeTabLang(getLangPref());
        //-->
      </script>
  </div><!-- header --><?cs 
/def ?>

<?cs 
def:sdk_nav() ?>
  <div class="g-section g-tpl-240" id="body-content">
    <div class="g-unit g-first not-resizable" id="side-nav">
      <div id="devdoc-nav"><?cs 
        include:"../../../../frameworks/base/docs/html/sdk/sdk_toc.cs" ?>
      </div>
    </div> <!-- end side-nav -->
<?cs /def ?>

<?cs 
def:resources_tab_nav() ?>
  <div class="g-section g-tpl-240" id="body-content">
    <div class="g-unit g-first side-nav-resizable" id="side-nav">
      <div id="devdoc-nav"><?cs 
        include:"../../../../frameworks/base/docs/html/resources/resources_toc.cs" ?>
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
    <div class="g-unit g-first side-nav-resizable" id="side-nav">
      <div id="devdoc-nav"><?cs 
        include:"../../../../frameworks/base/docs/html/guide/guide_toc.cs" ?>
      </div>
    </div> <!-- end side-nav -->
    <script>
      addLoadEvent(function() {
        scrollIntoView("devdoc-nav");
        });
    </script>
<?cs /def ?>

<?cs # The default side navigation for the reference docs ?><?cs 
def:default_left_nav() ?>
  <div class="g-section g-tpl-240" id="body-content">
    <div class="g-unit g-first side-nav-resizable" id="side-nav">
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
    <a href="http://www.android.com/terms.html">Site Terms of Service</a> -
    <a href="http://www.android.com/privacy.html">Privacy Policy</a> -
    <a href="http://www.android.com/branding.html">Brand Guidelines</a>
  </p><?cs 
/def ?>

<?cs # appears on the right side of the blue bar at the bottom off every page ?><?cs 
def:custom_buildinfo() ?>
  Android <?cs var:sdk.version ?>&nbsp;r<?cs var:sdk.rel.id ?> - <?cs var:page.now ?>
<?cs /def ?>
