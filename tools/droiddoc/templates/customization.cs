<?cs # This default template file is meant to be replaced.                      ?>
<?cs # Use the -templatedir arg to javadoc to set your own directory with a     ?>
<?cs # replacement for this file in it. ?>


<?cs def:default_search_box() ?><?cs /def ?>
<?cs def:default_left_nav() ?><?cs /def ?>

<?cs # appears at the top of every page ?><?cs 
def:custom_masthead() ?>
  <div id="header">
      <div id="headerLeft">
          <a href="<?cs var:toroot ?>index.html" tabindex="-1"><?cs var:page.title ?></a>
      </div>
      <div id="headerRight">
          <?cs if:!online-pdk ?>
            <?cs call:default_search_box() ?>
          <?cs /if ?>
      </div><!-- headerRight -->
  </div><!-- header --><?cs 
/def ?>

<?cs # appear at the bottom of every page ?>
<?cs def:custom_copyright() ?><?cs /def ?>
<?cs def:custom_cc_copyright() ?><?cs /def ?>
<?cs def:custom_footerlinks() ?><?cs /def ?>
<?cs def:custom_buildinfo() ?>Build <?cs var:page.build ?> - <?cs var:page.now ?><?cs /def ?>

<?cs # appears on the side of the page ?>
<?cs def:custom_left_nav() ?><?cs call:default_left_nav() ?><?cs /def ?>
