<div id="footer" class="wrap" <?cs if:fullpage ?>style="width:940px"<?cs /if ?>>
  <style>.feedback { float: right !Important }</style>
  <div class="feedback">
    <a href="#" class="button" onclick=" try {
      userfeedback.api.startFeedback({'productId':'715571','authuser':'1'});return false;}catch(e){}">Site Feedback</a>
  </div>
  <div id="copyright">
    <?cs call:custom_cc_copyright() ?>
  </div>
    <div id="footerlinks">
    <?cs call:custom_footerlinks() ?>
  </div>
