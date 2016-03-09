<?cs def:custom_masthead() ?>
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
    <div class="dac-header" id="header"><?cs call:butter_bar() ?>
      <div class="dac-header-inner">
        <a class="dac-nav-toggle" data-dac-toggle-nav href="javascript:;" title="Open navigation">
          <span class="dac-nav-hamburger">
            <span class="dac-nav-hamburger-top"></span>
            <span class="dac-nav-hamburger-mid"></span>
            <span class="dac-nav-hamburger-bot"></span>
          </span>
        </a>
        <?cs if:ndk ?><a class="dac-header-logo" href="<?cs var:toroot ?>ndk/index.html">
          <img class="dac-header-logo-image" src="<?cs var:toroot ?>assets/images/android_logo_ndk.png"
              srcset="<?cs var:toroot ?>assets/images/android_logo_ndk@2x.png 2x"
              width="32" height="36" alt="Android" /> NDK
          </a><?cs else ?><a class="dac-header-logo" href="<?cs var:toroot ?>index.html">
          <img class="dac-header-logo-image" src="<?cs var:toroot ?>assets/images/android_logo.png"
              srcset="<?cs var:toroot ?>assets/images/android_logo@2x.png 2x"
              width="32" height="36" alt="Android" /> Developers
          </a><?cs /if ?>

        <ul class="dac-header-crumbs">
          <?cs # More <li> elements added here with javascript ?>
          <?cs if:!section.landing ?><li class="dac-header-crumbs-item"><span class="dac-header-crumbs-link current <?cs
            if:ndk ?>ndk<?cs /if ?>"><?cs var:page.title ?></a></li><?cs
          /if ?>
        </ul>

        <?cs # ADD SEARCH AND MENU ?>
        <?cs if:!ndk ?>
        <?cs call:header_search_widget() ?>
        <?cs /if ?>

        <?cs if:ndk ?><a class="dac-header-console-btn" href="http://developer.android.com">
          <span class="dac-visible-desktop-inline">Back to Android Developers</span>
        </a><?cs else ?><a class="dac-header-console-btn" href="https://play.google.com/apps/publish/">
          <span class="dac-sprite dac-google-play"></span>
          <span class="dac-visible-desktop-inline">Developer</span>
          Console
        </a><?cs /if ?>

      </div><!-- end header-wrap.wrap -->
    </div><!-- end header -->

    <div id="searchResults" class="wrap" style="display:none;">
      <h2 id="searchTitle">Results</h2>
      <div id="leftSearchControl" class="search-control">Loading...</div>
    </div>
  </div> <!--end header-wrapper -->

  <?cs if:ndk ?>
  <!-- NDK Navigation-->
  <nav class="dac-nav">
    <div class="dac-nav-dimmer" data-dac-toggle-nav></div>

    <ul class="dac-nav-list" data-dac-nav>
      <li class="dac-nav-item dac-nav-head">
        <a class="dac-nav-link dac-nav-logo" data-dac-toggle-nav href="javascript:;" title="Close navigation">
          <img class="dac-logo-image" src="<?cs var:toroot ?>assets/images/android_logo_ndk.png"
               srcset="<?cs var:toroot ?>assets/images/android_logo_ndk@2x.png 2x"
               width="32" height="36" alt="Android" /> NDK
        </a>
      </li>
      <li class="dac-nav-item reference">
        <a class="dac-nav-link" href="<?cs var:toroot ?>ndk/reference/index.html"
           zh-tw-lang="參考資源"
           zh-cn-lang="参考"
           ru-lang="Справочник"
           ko-lang="참조문서"
           ja-lang="リファレンス"
           es-lang="Referencia">Reference</a>
      </li>
    </ul>
  </nav>
  <!-- end NDK navigation-->
  <?cs else ?>
  <!-- Navigation-->
  <nav class="dac-nav">
    <div class="dac-nav-dimmer" data-dac-toggle-nav></div>

    <ul class="dac-nav-list" data-dac-nav>
      <li class="dac-nav-item dac-nav-head">
        <a class="dac-nav-link dac-nav-logo" data-dac-toggle-nav href="javascript:;" title="Close navigation">
          <img class="dac-logo-image" src="<?cs var:toroot ?>assets/images/android_logo.png"
               srcset="<?cs var:toroot ?>assets/images/android_logo@2x.png 2x"
               width="32" height="36" alt="Android" /> Developers
        </a>
      </li>
      <li class="dac-nav-item develop">
        <a class="dac-nav-link has-subnav" href="/reference/packages.html" zh-tw-lang="參考資源" 
        zh-cn-lang="参考" ru-lang="Справочник" ko-lang="참조문서" ja-lang="リファレンス" 
        es-lang="Referencia">API Reference</a>
      <div class="dac-nav-secondary develop">
        <h1 style="font-size: 20px; line-height: 24px; margin: 20px; color:#444"
          >Android <?cs var:sdk.version ?> r<?cs var:sdk.rel.id ?>
        </h1>
      </div>
      </li>
    </ul>
  </nav>
  <!-- end navigation-->
  <?cs /if ?>
<?cs /if ?><?cs # end if/else !devsite ?>

<?cs
/def ?><?cs # end custom_masthead() ?>


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
