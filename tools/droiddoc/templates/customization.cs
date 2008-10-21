<?cs # This default template file is meant to be replaced. ?>
<?cs # Use the -tempatedir arg to javadoc to set your own directory with a replacement for this file in it. ?>
<?cs # As of OCT '08, there's no need to replace this... framework and gae are identical. ?>

<?cs def:custom_masthead() ?>
        <div id="header">
		<div id="headerLeft">
			<a href="<?cs var:toroot ?>"><img src="<?cs var:toroot ?>assets/images/bg_logo.jpg" /></a>
		</div>
		<div id="headerRight">
			<div id="headerLinks" align="right">
				<img src="<?cs var:toroot ?>assets/images/icon_world.jpg"><span class="text">&nbsp;<a href="#">English</a> | <a href="http://www.android.com">Android.com</a></span>
			</div>



			<div id="search" align="right">
				<div id="searchForm">
<form accept-charset="utf-8" class="gsc-search-box" onsubmit="document.location='<?cs var:toroot ?>search.html?' + document.getElementById('search_autocomplete').value; return false;">
  <table class="gsc-search-box" cellpadding="0" cellspacing="0"><tbody>
      <tr>
        <td class="gsc-input">
          <input id="search_autocomplete" class="gsc-input" type="text" size="33" autocomplete="off" tabindex="1"
            value="search developer docs" 
            onFocus="search_focus_changed(this, true)" 
            onBlur="search_focus_changed(this, false)" 
            onkeydown="return search_changed(event, true, '<?cs var:toroot?>')" 
            onkeyup="search_changed(event, false, '<?cs var:toroot?>')" />
        <br/>
        <div id="search_filtered_div">
            <table id="search_filtered" class="no-display" cellspacing=0>
            </table>
        </div>
        </td>
        <td class="gsc-search-button">
          <input type="button" value="Search" title="search" id="search-button" class="gsc-search-button" onclick="document.location='<?cs var:toroot ?>search.html?' + document.getElementById('search_autocomplete').value;"/>
        </td>
        <td class="gsc-clear-button">
          <div title="clear results" class="gsc-clear-button">&nbsp;</div>
        </td>
      </tr></tbody>
    </table>
</form>
</div>
			</div>
			<ul class="<?cs 
        if:reference ?>reference<?cs
        elif:guide ?>guide<?cs
        elif:sdk ?>sdk<?cs
        elif:home ?>home<?cs
        elif:community ?>community<?cs
        elif:publish ?>publish<?cs
        elif:about ?>about<?cs /if ?>">	
				<li><a href="<?cs var:toroot ?>community/" id="community-link">Community</a></li>
				<li><a href="http://android-developers.blogspot.com">Blog</a></li>
				//<li><a href="<?cs var:toroot ?>publish/" id="publish-link">Publish</a></li>
				<li><a href="<?cs var:toroot ?>reference/packages.html" id="reference-link">Reference</a></li>
				<li><a href="<?cs var:toroot ?>guide/" id="guide-link">Dev Guide</a></li>
				<li><a href="<?cs var:toroot ?>sdk/" id="sdk-link">SDK</a></li>	
				<li><a href="<?cs var:toroot ?>" id="home-link">Home</a></li>
			</ul>
		</div>
	</div>

<?cs /def ?>


<?cs # appears in the blue bar at the top of every page ?>
<?cs def:custom_subhead() ?>
    <?cs if:android.buglink ?>
        <a href="http://b/createIssue?component=27745&owner=jcohen&cc=android-bugs&issue.summary=javadoc+bug%3A+<?cs var:filename ?>&issue.type=BUG&issue.priority=P2&issue.severity=S2&"><font color="red">See a bug? Report it here.</font></a> &nbsp;&nbsp;
        
    <?cs /if ?>
<?cs /def ?>


<?cs def:custom_left_nav() ?>
<div class="g-section g-tpl-240" id="body-content">
  <div class="g-unit g-first side-nav-resizable" id="side-nav">
    <div id="resize-packages-nav">
      <div id="packages-nav">
        <div id="index-links"><nobr>
          <a href="<?cs var:toroot ?>reference/packages.html" <?cs if:(page.title == "Package Index") ?>class="selected"<?cs /if ?> >Package Index</a> | 
          <a href="<?cs var:toroot ?>reference/classes.html" <?cs if:(page.title == "Class Index") ?>class="selected"<?cs /if ?>>Class Index</a></nobr>
        </div>
        <ul>
        <?cs each:pkg=docs.packages ?>
          <li <?cs if:(class.package.name == pkg.name) || (package.name == pkg.name)?>class="selected"<?cs /if ?>><?cs call:package_link(pkg) ?></li>
        <?cs /each ?>
        </ul><br/>
      </div> <!-- end packages -->
    </div> <!-- end resize-packages -->
    <div id="classes-nav">
      <?cs if:subcount(class.package) ?>
      <ul>
        <?cs call:list("Interfaces", class.package.interfaces) ?>
        <?cs call:list("Classes", class.package.classes) ?>
        <?cs call:list("Enums", class.package.enums) ?>
        <?cs call:list("Exceptions", class.package.exceptions) ?>
        <?cs call:list("Errors", class.package.errors) ?>
      </ul>
      <?cs elif:subcount(package) ?>
      <ul>
        <?cs call:class_link_list("Interfaces", package.interfaces) ?>
        <?cs call:class_link_list("Classes", package.classes) ?>
        <?cs call:class_link_list("Enums", package.enums) ?>
        <?cs call:class_link_list("Exceptions", package.exceptions) ?>
        <?cs call:class_link_list("Errors", package.errors) ?>
      </ul>
      <?cs else ?>
        <script>
          /*addLoadEvent(maxPackageHeight);*/
        </script>
        <p style="padding:10px">Select a package to view its members</p>
      <?cs /if ?><br/>
    </div><!-- end classes -->
  </div> <!-- end side-nav -->
<?cs /def ?>

<?cs def:sdk_nav() ?>
<div class="g-section g-tpl-180" id="body-content">
  <div class="g-unit g-first" id="side-nav">
    <div id="devdoc-nav">
      <?cs include:"../../../java/android/html/sdk/sdk_toc.cs" ?>
    </div>
  </div> <!-- end side-nav -->
<?cs /def ?>

<?cs def:guide_nav() ?>
<div class="g-section g-tpl-240 side-nav-resizable" id="body-content">
  <div class="g-unit g-first" id="side-nav">
    <div id="devdoc-nav">
      <?cs include:"../../../java/android/html/guide/guide_toc.cs" ?>
    </div>
  </div> <!-- end side-nav -->
<?cs /def ?>

<?cs def:publish_nav() ?>
<div class="g-section g-tpl-180" id="body-content">
  <div class="g-unit g-first" id="side-nav">
    <div id="devdoc-nav">
      <?cs include:"../../../java/android/html/publish/publish_toc.cs" ?>
    </div>
  </div> <!-- end side-nav -->
<?cs /def ?>

<?cs # appears on the left side of the blue bar at the bottom of every page ?>
<?cs def:custom_copyright() ?>Copyright 2008 <a href="http://open.android.com/">The Android Open Source Project</a><?cs /def ?>

<?cs # appears on the right side of the blue bar at the bottom of every page ?>
<?cs def:custom_buildinfo() ?>Build <?cs var:page.build ?> - <?cs var:page.now ?><?cs /def ?>