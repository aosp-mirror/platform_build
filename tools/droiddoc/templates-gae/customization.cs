<?cs # appears above the blue bar at the top of every page ?>
<?cs def:custom_masthead() ?>
<?cs /def ?>


<?cs # appears in the blue bar at the top of every page ?>
<?cs def:custom_subhead() ?>SDK Documentation<?cs /def ?>

<?cs # appears on the left side of the blue bar at the bottom of every page ?>
<?cs def:custom_copyright() ?>Copyright 2007 XXX<?cs /def ?> 

<?cs # appears on the right side of the blue bar at the bottom of every page ?>
<?cs def:custom_buildinfo() ?>Built <?cs var:page.now ?><?cs /def ?>

<?cs def:custom_left_nav() ?>
<ul>
    <li><a href="<?cs var:toroot ?>documentation.html">Main Page</a></li>
    <li><a href="<?cs var:toroot ?>reference/packages.html">Package Index</a></li>
    <li><a href="<?cs var:toroot ?>reference/classes.html">Class Index</a></li>
    <li><a href="<?cs var:toroot ?>reference/hierarchy.html">Class Hierarchy</a></li>
    <li><a href="<?cs var:toroot ?>reference/keywords.html">Index</a></li>
</ul>
<?cs /def ?>

<?cs def:devdoc_left_nav() ?>
  <div id="devdoc-nav">
    <?cs include:"devdoc-nav.cs" ?>
  </div>
<?cs /def ?>