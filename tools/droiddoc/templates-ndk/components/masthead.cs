<?cs def:custom_masthead() ?>
<?cs if:preview ?>
  <?cs call:preview_masthead() ?>
<?cs else ?>
<a name="top"></a>

<!-- dialog to prompt lang pref change when loaded from hardcoded URL
<div id="langMessage" style="display:none">
  <div>
    <div class="lang en">
      <p>You requested a page in English, would you like to proceed with this language setting?</p>
    </div>
    <div class="lang es">
      <p>You requested a page in Spanish (Español), would you like to proceed with this language setting?</p>
    </div>
    <div class="lang ja">
      <p>You requested a page in Japanese (日本語), would you like to proceed with this language setting?</p>
    </div>
    <div class="lang ko">
      <p>You requested a page in Korean (한국어), would you like to proceed with this language setting?</p>
    </div>
    <div class="lang ru">
      <p>You requested a page in Russian (Русский), would you like to proceed with this language setting?</p>
    </div>
    <div class="lang zh-cn">
      <p>You requested a page in Simplified Chinese (简体中文), would you like to proceed with this language setting?</p>
    </div>
    <div class="lang zh-tw">
      <p>You requested a page in Traditional Chinese (繁體中文), would you like to proceed with this language setting?</p>
    </div>
    <a href="#" class="button yes" onclick="return false;">
      <span class="lang en">Yes</span>
      <span class="lang es">Sí</span>
      <span class="lang ja">Yes</span>
      <span class="lang ko">Yes</span>
      <span class="lang ru">Yes</span>
      <span class="lang zh-cn">是的</span>
      <span class="lang zh-tw">没有</span>
    </a>
    <a href="#" class="button" onclick="$('#langMessage').hide();return false;">
      <span class="lang en">No</span>
      <span class="lang es">No</span>
      <span class="lang ja">No</span>
      <span class="lang ko">No</span>
      <span class="lang ru">No</span>
      <span class="lang zh-cn">没有</span>
      <span class="lang zh-tw">没有</span>
    </a>
  </div>
</div> -->

<?cs if:!devsite ?><?cs # leave out the global header for devsite; it is in devsite template ?>
  <!-- Header -->
  <div id="header-wrapper">
    <div id="header"><?cs call:butter_bar() ?>
      <div class="wrap" id="header-wrap">
        <div class="col-3 logo">
          <a href="<?cs var:toroot ?>index.html">
            <img src="<?cs var:toroot ?>assets/images/dac_logo.png"
                srcset="<?cs var:toroot ?>assets/images/dac_logo@2x.png 2x"
                width="123" height="25" alt="Android Developers" />
          </a>
          <div class="btn-quicknav" id="btn-quicknav">
            <a href="#" class="arrow-inactive">Quicknav</a>
            <a href="#" class="arrow-active">Quicknav</a>
          </div>
        </div>

        <?cs # design/dev/dist tabs usually here ?>

        <?cs # call:header_search_widget() ?>

      </div><!-- end header-wrap.wrap -->
    </div><!-- end header -->


    <!-- Secondary x-nav -->
    <div id="nav-x">
        <div class="wrap" style="position:relative;z-index:1">

            <ul class="nav-x col-9 develop" style="width:100%">
                <li class="guide"><a href="<?cs var:toroot ?>ndk/guides/index.html">
                    Guides</a></li>
                <li class="reference"><a href="<?cs var:toroot ?>ndk/reference/index.html">
                    Reference</a></li>
                <li class="samples"><a href="<?cs var:toroot ?>ndk/samples/index.html">
                    Samples</a></li>
                <li class="downloads"><a href="<?cs var:toroot ?>ndk/downloads/index.html">
                    Downloads</a></li>
                </li>
            </ul>
        </div>
    </div>


    <div id="searchResults" class="wrap" style="display:none;">
      <h2 id="searchTitle">Results</h2>
      <div id="leftSearchControl" class="search-control">Loading...</div>
    </div>
  </div> <!--end header-wrapper -->

  <div id="sticky-header">
    <div>
      <a class="logo" href="#top"></a>
      <a class="top" href="#top"></a>
      <ul class="breadcrumb">
        <?cs # More <li> elements added here with javascript ?>
        <?cs if:!section.landing ?><li class="current"><?cs var:page.title ?></li><?cs
        /if ?>
      </ul>
    </div>
  </div>

<?cs /if ?><?cs # end if/else !devsite ?>
<?cs /if ?><?cs # end if/else preview ?><?cs
/def ?>

<?cs def:preview_masthead() ?>
<a name="top"></a>


<!-- Header -->
<div id="header-wrapper">
  <div id="header"><?cs call:butter_bar() ?>
    <div class="wrap" id="header-wrap">
      <div class="col_3 logo landing-logo" style="width:240px">
        <a href="<?cs var:toroot ?>preview/index.html">
          <img src="<?cs var:toroot ?>assets/images/android.png" height="25" alt="Android"
            style="margin:-3px 0 0" />
        </a>
      </div>
      <div class="col-8" style="margin:0"><h1 style="margin: 4px 0 0 0px;padding:0;line-height:16px;
color:#666;font-weight:100;font-size:27px;">L Developer Preview</h1></div>

      <?cs # ADD SEARCH AND MENU ?>
      <?cs # call:header_search_widget() ?>

    </div><!-- end header-wrap -->
  </div><!-- /Header -->


  <div id="searchResults" class="wrap" style="display:none;">
          <h2 id="searchTitle">Results</h2>
          <div id="leftSearchControl" class="search-control">Loading...</div>
  </div>
</div> <!--end header-wrapper -->

<div id="sticky-header">
  <div>
    <a class="logo" href="#top"></a>
    <a class="top" href="#top"></a>
    <ul class="breadcrumb">
      <?cs # More <li> elements added here with javascript ?>
      <?cs if:!section.landing ?><li class="current"><?cs var:page.title ?></li><?cs
      /if ?>
    </ul>
  </div>
</div>

  <?cs
/def ?>


<?cs # (UN)COMMENT THE INSIDE OF THIS METHOD TO TOGGLE VISIBILITY ?>
<?cs def:butter_bar() ?>

<?cs # HIDE THE BUTTER BAR

    <div style="height:20px"><!-- spacer to bump header down --></div>
    <div id="butterbar-wrapper">
      <div id="butterbar">
        <a href="http://googleblog.blogspot.com/" id="butterbar-message">
          The Android 5.0 SDK will be available on October 17th!
        </a>
      </div>
    </div>

?>

<?cs /def ?>
