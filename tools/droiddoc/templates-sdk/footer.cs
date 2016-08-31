<?cs # page footer content ?>
<div class="wrap">
  <div class="dac-footer<?cs if:fullpage ?> dac-landing<?cs /if ?>">
    <div class="cols dac-footer-main">
      <div class="col-1of2">
        <a class="dac-footer-getnews" id="newsletter" data-modal-toggle="newsletter" href="javascript:;">Get news &amp; tips <span
          class="dac-fab dac-primary"><i class="dac-sprite dac-mail"></i></span></a>
      </div>
      <div class="col-1of2 dac-footer-reachout">
        <div class="dac-footer-contact">
          <a class="dac-footer-contact-link" href="http://android-developers.blogspot.com/">Blog</a>
          <a class="dac-footer-contact-link" href="/support.html">Support</a>
        </div>
        <div class="dac-footer-social">
          <a class="dac-button-social dac-youtube dac-footer-social-link" href="https://www.youtube.com/user/androiddevelopers"><i class="dac-sprite dac-youtube"></i></a>
          <a class="dac-button-social dac-gplus dac-footer-social-link" href="https://plus.google.com/+AndroidDevelopers"><i class="dac-sprite dac-gplus"></i></a>
          <a class="dac-button-social dac-twitter dac-footer-social-link" href="https://twitter.com/AndroidDev"><i class="dac-sprite dac-twitter"></i></a>
        </div>
      </div>
    </div>

    <hr class="dac-footer-separator"/>

    <?cs if:reference ?>
      <p class="dac-footer-copyright">
        <?cs call:custom_copyright() ?>
      </p>
      <p class="dac-footer-build">
        <?cs call:custom_buildinfo() ?>
      </p>
    <?cs elif:!hide_license_footer ?>
      <p class="dac-footer-copyright">
        <?cs call:custom_cc_copyright() ?>
      </p>
    <?cs /if ?>

    <p class="dac-footer-links">
      <a href="/about/android.html">About Android</a>
      <a href="/auto/index.html">Auto</a>
      <a href="/tv/index.html">TV</a>
      <a href="/wear/index.html">Wear</a>
      <a href="/legal.html">Legal</a>

      <span id="language" class="locales">
        <select name="language" onchange="changeLangPref(this.value, true)">
          <option value="en" selected="selected">English</option>
          <option value="es">Español</option>
          <option value="in">Bahasa Indonesia</option>
          <option value="ja">日本語</option>
          <option value="ko">한국어</option>
          <option value="pt-br">Português Brasileiro</option>
          <option value="ru">Русский</option>
          <option value="vi">tiếng Việt</option>
          <option value="zh-cn">中文（简体)</option>
          <option value="zh-tw">中文（繁體)</option>
        </select>
      </span>
    </p>
  </div>
</div>
<!-- end footer -->

<?cs call:toast() ?>

<div data-modal="newsletter" data-newsletter data-swap class="dac-modal newsletter">
  <div class="dac-modal-container">
    <div class="dac-modal-window">
      <header class="dac-modal-header">
        <div class="dac-modal-header-actions">
          <button class="dac-modal-header-close" data-modal-toggle></button>
        </div>
        <div class="dac-swap" data-swap-container>
          <section class="dac-swap-section dac-active dac-down">
            <h2 class="norule dac-modal-header-title" data-t="newsletter.title"></h2>
            <p class="dac-modal-header-subtitle" data-t="newsletter.requiredHint"></p>
          </section>
          <section class="dac-swap-section dac-up">
            <h2 class="norule dac-modal-header-title" data-t="newsletter.successTitle">Hooray!</h2>
          </section>
        </div>
      </header>
      <div class="dac-swap" data-swap-container>
        <section class="dac-swap-section dac-active dac-left">
          <form action="https://docs.google.com/forms/d/1QgnkzbEJIDu9lMEea0mxqWrXUJu0oBCLD7ar23V0Yys/formResponse" class="dac-form" method="post" target="dac-newsletter-iframe">
            <input type="hidden" name="entry.935454734" data-newsletter-language>
            <section class="dac-modal-content">
              <fieldset class="dac-form-fieldset">
                <div class="cols">
                  <div class="col-1of2 newsletter-leftCol">
                    <div class="dac-form-input-group">
                      <label for="newsletter-full-name" class="dac-form-floatlabel" data-t="newsletter.name">Full name</label>
                      <input type="text" class="dac-form-input" name="entry.1357890476" id="newsletter-full-name" required>
                      <span class="dac-form-required">*</span>
                    </div>
                    <div class="dac-form-input-group">
                      <label for="newsletter-email" class="dac-form-floatlabel" data-t="newsletter.email">Email address</label>
                      <input type="email" class="dac-form-input" name="entry.472100832" id="newsletter-email" required>
                      <span class="dac-form-required">*</span>
                    </div>
                  </div>
                  <div class="col-1of2 newsletter-rightCol">
                    <div class="dac-form-input-group">
                      <label for="newsletter-company" class="dac-form-floatlabel" data-t="newsletter.company">Company / developer name</label>
                      <input type="text" class="dac-form-input" name="entry.1664780309" id="newsletter-company">
                    </div>
                    <div class="dac-form-input-group">
                      <label for="newsletter-play-store" class="dac-form-floatlabel" data-t="newsletter.appUrl">One of your Play Store app URLs</label>
                      <input type="url" class="dac-form-input" name="entry.47013838" id="newsletter-play-store" required>
                      <span class="dac-form-required">*</span>
                    </div>
                  </div>
                </div>
              </fieldset>
              <fieldset class="dac-form-fieldset">
                <div class="cols">
                  <div class="col-1of2 newsletter-leftCol">
                    <legend class="dac-form-legend"><span data-t="newsletter.business.label">Which best describes your business:</span><span class="dac-form-required">*</span>
                    </legend>
                    <div class="dac-form-radio-group">
                      <input type="radio" value="Apps" class="dac-form-radio" name="entry.1796324055" id="newsletter-business-type-app" required>
                      <label for="newsletter-business-type-app" class="dac-form-radio-button"></label>
                      <label for="newsletter-business-type-app" class="dac-form-label" data-t="newsletter.business.apps">Apps</label>
                    </div>
                    <div class="dac-form-radio-group">
                      <input type="radio" value="Games" class="dac-form-radio" name="entry.1796324055" id="newsletter-business-type-games" required>
                      <label for="newsletter-business-type-games" class="dac-form-radio-button"></label>
                      <label for="newsletter-business-type-games" class="dac-form-label" data-t="newsletter.business.games">Games</label>
                    </div>
                    <div class="dac-form-radio-group">
                      <input type="radio" value="Apps and Games" class="dac-form-radio" name="entry.1796324055" id="newsletter-business-type-appsgames" required>
                      <label for="newsletter-business-type-appsgames" class="dac-form-radio-button"></label>
                      <label for="newsletter-business-type-appsgames" class="dac-form-label" data-t="newsletter.business.both">Apps &amp; Games</label>
                    </div>
                  </div>
                  <div class="col-1of2 newsletter-rightCol newsletter-checkboxes">
                    <div class="dac-form-radio-group">
                      <div class="dac-media">
                        <div class="dac-media-figure">
                          <input type="checkbox" class="dac-form-checkbox" name="entry.732309842" id="newsletter-add" required value="Add me to the mailing list for the monthly newsletter and occasional emails about development and Google Play opportunities.">
                          <label for="newsletter-add" class="dac-form-checkbox-button"></label>
                        </div>
                        <div class="dac-media-body">
                          <label for="newsletter-add" class="dac-form-label dac-form-aside"><span data-t="newsletter.confirmMailingList"></span><span class="dac-form-required">*</span></label>
                        </div>
                      </div>
                    </div>
                    <div class="dac-form-radio-group">
                      <div class="dac-media">
                        <div class="dac-media-figure">
                          <input type="checkbox" class="dac-form-checkbox" name="entry.2045036090" id="newsletter-terms" required value="I acknowledge that the information provided in this form will be subject to Google's privacy policy (https://www.google.com/policies/privacy/).">
                          <label for="newsletter-terms" class="dac-form-checkbox-button"></label>
                        </div>
                        <div class="dac-media-body">
                          <label for="newsletter-terms" class="dac-form-label dac-form-aside"><span data-t="newsletter.privacyPolicy" data-t-html></span><span class="dac-form-required">*</span></label>
                        </div>
                      </div>
                    </div>
                  </div>
                </div>
              </fieldset>
            </section>
            <footer class="dac-modal-footer">
              <div class="cols">
                <div class="col-2of5">
                </div>
              </div>
              <button type="submit" value="Submit" class="dac-fab dac-primary dac-large dac-modal-action"><i class="dac-sprite dac-arrow-right"></i></button>
            </footer>
          </form>
        </section>
        <section class="dac-swap-section dac-right">
          <div class="dac-modal-content">
            <p class="newsletter-success-message" data-t="newsletter.successDetails"></p>
          </div>
        </section>
      </div>
    </div>
  </div>
</div>
<!-- end newsletter modal -->

<!-- start reset language header modal -->
<div data-modal="langform" class="dac-modal" id="langform">
  <div class="dac-modal-container">
    <div class="dac-modal-window">
      <header class="dac-modal-header">
        <div class="dac-modal-header-actions">
          <button class="dac-modal-header-close" data-modal-toggle></button>
        </div>
        <section class="dac-swap-section dac-active dac-down">
          <h2 class="norule dac-modal-header-title"></h2>
        </section>
      </header>
      <section class="dac-swap-section dac-active dac-left">
          <section class="dac-modal-content">
            <fieldset class="dac-form-fieldset">
              <div class="cols">
                <div class="col-2of2 langform-leftCol">
                  <p id="resetLangText"></p>
                  <p id="resetLangCta"></p>
                </div>
              </div>
            </fieldset>
          </section>
          <footer class="dac-modal-footer" id="langfooter">
            <div class="cols">
              <div class="col-2of5">
              </div>
            </div>
              <button class="button dac-primary dac-modal-action lang yes" data-t="newsletter.resetLangButtonYes" data-modal-toggle></button>
              <button class="button dac-primary dac-modal-action lang no" data-t="newsletter.resetLangButtonNo" data-modal-toggle></button>
            </a>
          </footer>
        </form>
      </section>
    </div>
  </div>
</div>
<!-- end langreset modal -->
