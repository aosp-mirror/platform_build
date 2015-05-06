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
        <ul class="nav-x col-9">
            <li class="design">
              <a href="<?cs var:toroot ?>design/index.html"
              zh-tw-lang="設計"
              zh-cn-lang="设计"
              ru-lang="Проектирование"
              ko-lang="디자인"
              ja-lang="設計"
              es-lang="Diseñar"
              >Design</a></li>
            <li class="develop"><a href="<?cs var:toroot ?>develop/index.html"
              zh-tw-lang="開發"
              zh-cn-lang="开发"
              ru-lang="Разработка"
              ko-lang="개발"
              ja-lang="開発"
              es-lang="Desarrollar"
              >Develop</a></li>
            <li class="distribute last"><a href="<?cs var:toroot ?>distribute/<?cs
              if:android.whichdoc == "offline" ?>googleplay/<?cs /if ?>index.html"
              zh-tw-lang="發佈"
              zh-cn-lang="分发"
              ru-lang="Распространение"
              ko-lang="배포"
              ja-lang="配布"
              es-lang="Distribuir"
              >Distribute</a></li>
        </ul>


        <?cs # ADD SEARCH AND MENU ?>
        <?cs call:header_search_widget() ?>


        <!-- Expanded quicknav -->
        <div id="quicknav" class="col-13">
          <ul>
            <li class="about">
              <ul>
                <li><a href="<?cs var:toroot ?>about/index.html">About</a></li>
                <li><a href="<?cs var:toroot ?>wear/index.html">Wear</a></li>
                <li><a href="<?cs var:toroot ?>tv/index.html">TV</a></li>
                <li><a href="<?cs var:toroot ?>auto/index.html">Auto</a></li>
              </ul>
            </li>
            <li class="design">
              <ul>
                <li><a href="<?cs var:toroot ?>design/index.html">Get Started</a></li>
                <li><a href="<?cs var:toroot ?>design/devices.html">Devices</a></li>
                <li><a href="<?cs var:toroot ?>design/style/index.html">Style</a></li>
                <li><a href="<?cs var:toroot ?>design/patterns/index.html">Patterns</a></li>
                <li><a href="<?cs var:toroot ?>design/building-blocks/index.html">Building Blocks</a></li>
                <li><a href="<?cs var:toroot ?>design/downloads/index.html">Downloads</a></li>
                <li><a href="<?cs var:toroot ?>design/videos/index.html">Videos</a></li>
              </ul>
            </li>
            <li class="develop">
              <ul>
                <li><a href="<?cs var:toroot ?>training/index.html"
                  zh-tw-lang="訓練課程"
                  zh-cn-lang="培训"
                  ru-lang="Курсы"
                  ko-lang="교육"
                  ja-lang="トレーニング"
                  es-lang="Capacitación"
                  >Training</a></li>
                <li><a href="<?cs var:toroot ?>guide/index.html"
                  zh-tw-lang="API 指南"
                  zh-cn-lang="API 指南"
                  ru-lang="Руководства по API"
                  ko-lang="API 가이드"
                  ja-lang="API ガイド"
                  es-lang="Guías de la API"
                  >API Guides</a></li>
                <li><a href="<?cs var:toroot ?>reference/packages.html"
                  zh-tw-lang="參考資源"
                  zh-cn-lang="参考"
                  ru-lang="Справочник"
                  ko-lang="참조문서"
                  ja-lang="リファレンス"
                  es-lang="Referencia"
                  >Reference</a></li>
                <li><a href="<?cs var:toroot ?>sdk/index.html"
                  zh-tw-lang="相關工具"
                  zh-cn-lang="工具"
                  ru-lang="Инструменты"
                  ko-lang="도구"
                  ja-lang="ツール"
                  es-lang="Herramientas"
                  >Tools</a>
                </li>
                <li><a href="<?cs var:toroot ?>google/index.html">Google Services</a>
                </li>
                <?cs if:android.hasSamples ?>
                  <li><a href="<?cs var:toroot ?>samples/index.html">Samples</a>
                  </li>
                <?cs /if ?>
              </ul>
            </li>
            <li class="distribute last">
              <ul>
                <li><a href="<?cs var:toroot ?>distribute/googleplay/index.html">Google Play</a></li>
                <li><a href="<?cs var:toroot ?>distribute/essentials/index.html">Essentials</a></li>
                <li><a href="<?cs var:toroot ?>distribute/users/index.html">Get Users</a></li>
                <li><a href="<?cs var:toroot ?>distribute/engage/index.html">Engage &amp; Retain</a></li>
                <li><a href="<?cs var:toroot ?>distribute/monetize/index.html">Monetize</a></li>
                <li><a href="<?cs var:toroot ?>distribute/analyze/index.html">Analyze</a></li>
                <li><a href="<?cs var:toroot ?>distribute/tools/index.html">Tools &amp; Reference</a></li>
                <li><a href="<?cs var:toroot ?>distribute/stories/index.html">Developer Stories</a></li>
              </ul>
            </li>
          </ul>
        </div><!-- /Expanded quicknav -->
      </div><!-- end header-wrap.wrap -->
    </div><!-- end header -->

  <?cs if:about || wear || tv || auto ?>
    <!-- Secondary x-nav -->
    <div id="nav-x">
        <div class="wrap">
            <ul class="nav-x col-9 about" style="width:100%">
                <li class="about"><a href="<?cs var:toroot ?>about/index.html"
                  >About</a></li>
                <li class="wear"><a href="<?cs var:toroot ?>wear/index.html"
                  >Wear</a></li>
                <li class="tv"><a href="<?cs var:toroot ?>tv/index.html"
                  >TV</a></li>
                <li class="auto"><a href="<?cs var:toroot ?>auto/index.html"
                  >Auto</a></li>
            </ul>
        </div>
    </div>
    <!-- /Sendondary x-nav ABOUT -->



  <?cs elif:training || guide || reference || tools || develop || google || samples ?>
    <!-- Secondary x-nav -->
    <div id="nav-x">
        <div class="wrap" style="position:relative;z-index:1">

        <?cs if:reference ?>

        <?cs /if ?>

            <ul class="nav-x col-9 develop" style="width:100%">
                <li class="training"><a href="<?cs var:toroot ?>training/index.html"
                  zh-tw-lang="訓練課程"
                  zh-cn-lang="培训"
                  ru-lang="Курсы"
                  ko-lang="교육"
                  ja-lang="トレーニング"
                  es-lang="Capacitación"
                  >Training</a></li>
                <li class="guide"><a href="<?cs var:toroot ?>guide/index.html"
                  zh-tw-lang="API 指南"
                  zh-cn-lang="API 指南"
                  ru-lang="Руководства по API"
                  ko-lang="API 가이드"
                  ja-lang="API ガイド"
                  es-lang="Guías de la API"
                  >API Guides</a></li>
                <li class="reference"><a href="<?cs var:toroot ?>reference/packages.html"
                  zh-tw-lang="參考資源"
                  zh-cn-lang="参考"
                  ru-lang="Справочник"
                  ko-lang="참조문서"
                  ja-lang="リファレンス"
                  es-lang="Referencia"
                  >Reference</a></li>
                <li class="tools"><a href="<?cs var:toroot ?>sdk/index.html"
                  zh-tw-lang="相關工具"
                  zh-cn-lang="工具"
                  ru-lang="Инструменты"
                  ko-lang="도구"
                  ja-lang="ツール"
                  es-lang="Herramientas"
                  >Tools</a></li>
                <li class="google"><a href="<?cs var:toroot ?>google/index.html"
                  >Google Services</a>
                </li>
                <?cs if:android.hasSamples ?>
                  <li class="samples"><a href="<?cs var:toroot ?>samples/index.html"
                    >Samples</a>
                  </li>
                <?cs /if ?>
            </ul>
        </div>
    </div>
    <!-- /Sendondary x-nav DEVELOP -->

  <?cs elif:distribute || googleplay || essentials || users || engage || monetize || analyze ||  disttools || stories ?>
    <!-- Secondary distribute x-nav -->
    <div id="nav-x">
        <div class="wrap">
            <ul class="nav-x distribute">
                <li class="googleplay"><a href="<?cs var:toroot ?>distribute/googleplay/index.html"
                  >Google Play</a></li>
                <li class="essentials"><a href="<?cs var:toroot ?>distribute/essentials/index.html"
                  >Essentials</a></li>
                <li class="users"><a href="<?cs var:toroot ?>distribute/users/index.html"
                  >Get Users</a></li>
                <li class="engage"><a href="<?cs var:toroot ?>distribute/engage/index.html"
                  >Engage &amp; Retain</a></li>
                <li class="monetize"><a href="<?cs var:toroot ?>distribute/monetize/index.html"
                  >Monetize</a>
                </li>
                <li class="analyze"><a href="<?cs var:toroot ?>distribute/analyze/index.html"
                  >Analyze</a>
                </li>
                <li class="disttools"><a href="<?cs var:toroot ?>distribute/tools/index.html"
                  >Tools</a>
                </li>
                <li class="stories"><a href="<?cs var:toroot ?>distribute/stories/index.html"
                  >Stories</a>
                </li>
            </ul>
            <a href="https://play.google.com/apps/publish/" class="developer-console-btn">Developer Console</a>
        </div> <!-- /Secondary distribute x-nav -->
    </div>
    <!-- /Sendondary x-nav DISTRIBUTE -->
  <?cs /if ?>

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
color:#666;font-weight:100;font-size:27px;">M Developer Preview</h1></div>

      <?cs # ADD SEARCH AND MENU ?>
      <?cs call:header_search_widget() ?>

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
          The Android {version_number} SDK will be available on {Month} {Day}!
        </a>
      </div>
    </div>

?>

<?cs /def ?>
