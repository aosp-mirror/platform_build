<?cs def:custom_masthead() ?>
  <a name="top"></a>
  <!-- Header -->
  <div id="header-wrapper">
    <div class="dac-header <?cs if:ndk ?>dac-ndk<?cs /if ?>" id="header">
      <div class="dac-header-inner">
        <a class="dac-nav-toggle" data-dac-toggle-nav href="javascript:;" title="Open navigation">
          <span class="dac-nav-hamburger">
            <span class="dac-nav-hamburger-top"></span>
            <span class="dac-nav-hamburger-mid"></span>
            <span class="dac-nav-hamburger-bot"></span>
          </span>
        </a>
        <?cs if:ndk ?><a class="dac-header-logo" style="width:144px;" href="<?cs var:toroot
        ?>ndk/index.html">
          <img class="dac-header-logo-image" src="<?cs var:toroot ?>assets/images/android_logo.png"
              srcset="<?cs var:toroot ?>assets/images/android_logo@2x.png 2x"
              width="32" height="36" alt="Android" /> NDK
          </a><?cs else ?><a class="dac-header-logo" href="<?cs var:toroot ?>index.html">
          <img class="dac-header-logo-image" src="<?cs var:toroot ?>assets/images/android_logo.png"
              srcset="<?cs var:toroot ?>assets/images/android_logo@2x.png 2x"
              width="32" height="36" alt="Android" /> Developers
          </a><?cs /if ?>

        <?cs if:ndk
        ?><ul class="dac-header-tabs">
          <li>
            <a href="<?cs var:toroot ?>ndk/guides/index.html" class="dac-header-tab"
            zh-tw-lang="API 指南"
            zh-cn-lang="API 指南"
            ru-lang="Руководства по API"
            ko-lang="API 가이드"
            ja-lang="API ガイド"
            es-lang="Guías de la API">Guides</a>
          </li>
          <li>
            <a href="<?cs var:toroot ?>ndk/reference/index.html" class="dac-header-tab"
            zh-tw-lang="參考資源"
            zh-cn-lang="参考"
            ru-lang="Справочник"
            ko-lang="참조문서"
            ja-lang="リファレンス"
            es-lang="Referencia">Reference</a>
          </li>
          <li>
            <a href="<?cs var:toroot ?>ndk/samples/index.html" class="dac-header-tab"
           >Samples</a>
          </li>
          <li>
            <a href="<?cs var:toroot ?>ndk/downloads/index.html" class="dac-header-tab"
            >Downloads</a>
          </li>
        </ul><?cs else
        ?><?cs
        #
        # For the reference only docs, include just one tab
        #
        ?><?cs if:referenceonly
          ?><ul class="dac-header-tabs">
            <li><a href="<?cs var:toroot ?>reference/packages.html" class="dac-header-tab"><?cs
              if:sdk.preview
                ?>Android <?cs var:sdk.codename ?>
                  Preview <?cs var:sdk.preview.version ?><?cs
              else
                ?>Android <?cs var:sdk.version ?>
                  r<?cs var:sdk.rel.id ?><?cs
              /if ?></a>
            </li>
          </ul>
        <?cs else ?><?cs
        #
        # End reference only docs, now the online DAC tabs...
        #
        ?><ul class="dac-header-tabs">
          <li>
          <a class="dac-header-tab" href="<?cs var:toroot ?>design/index.html"
             zh-tw-lang="設計"
             zh-cn-lang="设计"
             ru-lang="Проектирование"
             ko-lang="디자인"
             ja-lang="設計"
             es-lang="Diseñar">Design</a>
          </li>
          <li>
          <a class="dac-header-tab" href="<?cs var:toroot ?>develop/index.html"
             zh-tw-lang="開發"
             zh-cn-lang="开发"
             ru-lang="Разработка"
             ko-lang="개발"
             ja-lang="開発"
             es-lang="Desarrollar">Develop</a>
          </li>
          <li>
          <a class="dac-header-tab" href="<?cs var:toroot ?>distribute/index.html"
             zh-tw-lang="發佈"
             zh-cn-lang="分发"
             ru-lang="Распространение"
             ko-lang="배포"
             ja-lang="配布"
             es-lang="Distribuir">Distribute</a>
          </li>
        </ul><?cs
        /if ?><?cs
        #
        # End if/else reference only docs
        #
        ?><?cs
        /if ?><?cs # end if/else ndk ?>

        <?cs if:ndk ?><a class="dac-header-console-btn" href="http://developer.android.com">
          Back to Android Developers
        </a><?cs else ?><a class="dac-header-console-btn" href="https://play.google.com/apps/publish/">
          <span class="dac-sprite dac-google-play"></span>
          <span class="dac-visible-desktop-inline">Developer</span>
          Console
        </a><?cs /if ?><?cs

        # ADD SEARCH AND MENU ?><?cs
        if:!ndk ?><?cs
          if:!referenceonly ?><?cs
            call:header_search_widget() ?><?cs
          /if ?><?cs
        /if ?>
      </div><!-- end header-wrap.wrap -->
    </div><!-- end header -->
  </div> <!--end header-wrapper -->

  <?cs if:ndk ?>
  <!-- NDK Navigation-->
  <nav class="dac-nav">
    <div class="dac-nav-dimmer" data-dac-toggle-nav></div>

    <div class="dac-nav-sidebar" data-swap data-dynamic="false" data-transition-speed="300" data-dac-nav>
                   <div data-swap-container>
        <?cs call:custom_left_nav() ?>
      <ul id="dac-main-navigation" class="dac-nav-list dac-swap-section dac-left dac-no-anim">
      <li class="dac-nav-item guides">
        <a class="dac-nav-link" href="<?cs var:toroot ?>ndk/guides/index.html"
           zh-tw-lang="API 指南"
           zh-cn-lang="API 指南"
           ru-lang="Руководства по API"
           ko-lang="API 가이드"
           ja-lang="API ガイド"
           es-lang="Guías de la API">Guides</a>
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
      <li class="dac-nav-item samples">
        <a class="dac-nav-link" href="<?cs var:toroot ?>ndk/samples/index.html"
           >Samples</a>
      </li>
      <li class="dac-nav-item downloads">
        <a class="dac-nav-link" href="<?cs var:toroot ?>ndk/downloads/index.html"
           >Downloads</a>
      </li>
      </ul>
    </div>
                       </div>
  </nav>
  <!-- end NDK navigation-->



  <?cs else ?>
  <!-- Navigation-->
  <nav class="dac-nav">
    <div class="dac-nav-dimmer" data-dac-toggle-nav></div>

    <div class="dac-nav-sidebar" data-swap data-dynamic="false" data-transition-speed="300" data-dac-nav>
      <div <?cs if:!referenceonly ?>data-swap-container<?cs /if ?>>
        <?cs call:custom_left_nav() ?>
        <?cs if:!referenceonly ?>
        <ul id="dac-main-navigation" class="dac-nav-list dac-swap-section dac-left dac-no-anim">
        <li class="dac-nav-item home">
          <a class="dac-nav-link" href="<?cs var:toroot ?>index.html">Home</a>
          <i class="dac-sprite dac-expand-more-black dac-nav-sub-slider"></i>
          <ul class="dac-nav-secondary about">
            <li class="dac-nav-item versions">
              <a class="dac-nav-link" href="<?cs var:toroot ?>about/versions/nougat/index.html">Android</a>
            </li>
            <li class="dac-nav-item wear">
              <a class="dac-nav-link" href="<?cs var:toroot ?>wear/index.html">Wear</a>
            </li>
            <li class="dac-nav-item tv">
              <a class="dac-nav-link" href="<?cs var:toroot ?>tv/index.html">TV</a>
            </li>
            <li class="dac-nav-item auto">
              <a class="dac-nav-link" href="<?cs var:toroot ?>auto/index.html">Auto</a>
            </li>
          </ul>
        </li>
        <li class="dac-nav-item design">
          <a class="dac-nav-link" href="<?cs var:toroot ?>design/index.html"
             zh-tw-lang="設計"
             zh-cn-lang="设计"
             ru-lang="Проектирование"
             ko-lang="디자인"
             ja-lang="設計"
             es-lang="Diseñar">Design</a>
        </li>
        <li class="dac-nav-item develop">
          <a class="dac-nav-link" href="<?cs var:toroot ?>develop/index.html"
             zh-tw-lang="開發"
             zh-cn-lang="开发"
             ru-lang="Разработка"
             ko-lang="개발"
             ja-lang="開発"
             es-lang="Desarrollar">Develop</a>
          <i class="dac-sprite dac-expand-more-black dac-nav-sub-slider"></i>
          <ul class="dac-nav-secondary develop">
            <li class="dac-nav-item training">
              <a class="dac-nav-link" href="<?cs var:toroot ?>training/index.html"
                 zh-tw-lang="訓練課程"
                 zh-cn-lang="培训"
                 ru-lang="Курсы"
                 ko-lang="교육"
                 ja-lang="トレーニング"
                 es-lang="Capacitación">Training</a>
            </li>
            <li class="dac-nav-item guide">
              <a class="dac-nav-link" href="<?cs var:toroot ?>guide/index.html"
                 zh-tw-lang="API 指南"
                 zh-cn-lang="API 指南"
                 ru-lang="Руководства по API"
                 ko-lang="API 가이드"
                 ja-lang="API ガイド"
                 es-lang="Guías de la API">API Guides</a>
            </li>
            <li class="dac-nav-item reference">
              <a class="dac-nav-link" href="<?cs var:toroot ?>reference/packages.html"
                 zh-tw-lang="參考資源"
                 zh-cn-lang="参考"
                 ru-lang="Справочник"
                 ko-lang="참조문서"
                 ja-lang="リファレンス"
                 es-lang="Referencia">Reference</a>
            </li>
            <li class="dac-nav-item tools">
              <a class="dac-nav-link" href="<?cs var:toroot ?>sdk/index.html"
                 zh-tw-lang="相關工具"
                 zh-cn-lang="工具"
                 ru-lang="Инструменты"
                 ko-lang="도구"
                 ja-lang="ツール"
                 es-lang="Herramientas">Tools</a></li>
            <li class="dac-nav-item google">
              <a class="dac-nav-link" href="<?cs var:toroot ?>google/index.html">Google Services</a>
            </li>
            <?cs if:android.hasSamples ?>
            <li class="dac-nav-item samples">
              <a class="dac-nav-link" href="<?cs var:toroot ?>samples/index.html">Samples</a>
            </li>
            <?cs /if ?>
          </ul>
        </li>
        <li class="dac-nav-item distribute">
          <a class="dac-nav-link" href="<?cs var:toroot ?>distribute/<?cs if:android.whichdoc == 'offline' ?>googleplay/<?cs /if ?>index.html"
             zh-tw-lang="發佈"
             zh-cn-lang="分发"
             ru-lang="Распространение"
             ko-lang="배포"
             ja-lang="配布"
             es-lang="Distribuir">Distribute</a>
          <i class="dac-sprite dac-expand-more-black dac-nav-sub-slider"></i>
          <ul class="dac-nav-secondary distribute">
            <li class="dac-nav-item googleplay">
              <a class="dac-nav-link" href="<?cs var:toroot ?>distribute/googleplay/index.html">Google Play</a></li>
            <li class="dac-nav-item essentials">
              <a class="dac-nav-link" href="<?cs var:toroot ?>distribute/essentials/index.html">Essentials</a></li>
            <li class="dac-nav-item users">
              <a class="dac-nav-link" href="<?cs var:toroot ?>distribute/users/index.html">Get Users</a></li>
            <li class="dac-nav-item engage">
              <a class="dac-nav-link" href="<?cs var:toroot ?>distribute/engage/index.html">Engage &amp; Retain</a></li>
            <li class="dac-nav-item monetize">
              <a class="dac-nav-link" href="<?cs var:toroot ?>distribute/monetize/index.html">Earn</a>
            </li>
            <li class="dac-nav-item analyze">
              <a class="dac-nav-link" href="<?cs var:toroot ?>distribute/analyze/index.html">Analyze</a>
            </li>
            <li class="dac-nav-item stories">
              <a class="dac-nav-link" href="<?cs var:toroot ?>distribute/stories/index.html">Stories</a>
            </li>
          </ul>
        </li>
        <!--<li class="dac-nav-item preview">
          <a class="dac-nav-link" href="<?cs var:toroot ?>preview/index.html">Preview</a>
        </li>-->
        </ul>
        <?cs /if ?><?cs # end if referenceonly ?>
      </div>
    </div>
  </nav>
  <!-- end navigation-->
  <?cs /if ?>

<!-- Nav Setup -->
<script>$('[data-dac-nav]').dacNav();</script>

<?cs
/def ?><?cs # end custom_masthead() ?><?cs

def:toast() ?><?cs

# (UN)COMMENT TO TOGGLE VISIBILITY

  <div class="dac-toast-group">
    <div class="dac-toast" data-toast>
      <div class="dac-toast-wrap">
        This is a demo notification <a href="#">Learn more</a>.
      </div>
    </div>
  </div>

?><?cs
/def ?>