<?cs def:custom_masthead() ?>
<?cs if:wear ?>
  <?cs call:wear_masthead() ?>
<?cs else ?>
<a name="top"></a>
<?cs if:!devsite ?><?cs # leave out the global header for devsite; it is in devsite template ?>
  <!-- Header -->
  <div id="header-wrapper">
    <div id="header">
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
        <div id="quicknav" class="col-9">
          <ul>
            <li class="design">
              <ul>
                <li><a href="<?cs var:toroot ?>design/index.html">Get Started</a></li>
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
                <li><a href="<?cs var:toroot ?>tools/index.html"
                  zh-tw-lang="相關工具"
                  zh-cn-lang="工具"
                  ru-lang="Инструменты"
                  ko-lang="도구"
                  ja-lang="ツール"
                  es-lang="Herramientas"
                  >Tools</a>
                  <ul><li><a href="<?cs var:toroot ?>sdk/index.html">Get the SDK</a></li></ul>
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
                <li><a href="<?cs var:toroot ?>distribute/tools/index.html">Tools &amp; Reference</a></li>
                <li><a href="<?cs var:toroot ?>distribute/stories/index.html">Developer Stories</a></li>
              </ul>
            </li>
          </ul>
        </div><!-- /Expanded quicknav -->
      </div><!-- end header-wrap.wrap -->
    </div><!-- end header -->

  <?cs if:training || guide || reference || tools || develop || google || samples ?>
    <!-- Secondary x-nav -->
    <div id="nav-x">
        <div class="wrap">
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
                <li class="tools"><a href="<?cs var:toroot ?>tools/index.html"
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
    <!-- /Sendondary x-nav -->

  <?cs elif:distribute || googleplay || essentials || users || engage || monetize || disttools || stories ?>
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
<?cs /if ?><?cs # end if/else wear ?><?cs
/def ?>

<?cs def:wear_masthead() ?>
<a name="top"></a>

<!-- Header -->
<div id="header-wrapper">
  <div id="header">
    <div class="wrap" id="header-wrap">
      <div class="col_3 logo wear-logo">
        <a href="<?cs var:toroot ?>wear/index.html">
          <img src="<?cs var:toroot ?>wear/images/android-wear.png" height="16" alt="Android Wear" />
        </a>
      </div>
      <div class="col-8" style="margin:0"><h1 style="margin:1px 0 0 20px;padding:0;line-height:16px;
color:#666;font-weight:100;font-size:24px;">Developer Preview</h1></div>

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
