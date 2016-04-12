<div id="footer" class="wrap" <?cs if:fullpage ?>style="width:940px"<?cs /if ?>>
        
<?cs if:reference ?>
  <div id="copyright">
    <?cs call:custom_copyright() ?>
  </div>
  <div id="build_info">
    <?cs call:custom_buildinfo() ?>
  </div>
<?cs elif:!hide_license_footer ?>
  <div id="copyright">
    <?cs call:custom_cc_copyright() ?>
  </div>
<?cs /if ?>
<?cs if:!no_footer_links ?>
  <div id="footerlinks">
    <?cs call:custom_footerlinks() ?>
  </div>
<?cs /if ?>
</div> <!-- end footer -->