<?cs # appears above the blue bar at the top of every page ?>

<?cs def:custom_masthead() ?>
</div>
<?cs /def ?>


<?cs # appears in the blue bar at the top of every page ?>
<?cs def:custom_subhead() ?>
    <?cs if:android.buglink ?>
    <?cs /if ?>
<?cs /def ?>

<?cs # appears on the left side of the blue bar at the bottom of every page ?>
<?cs def:custom_copyright() ?><?cs /def ?>

<?cs # appears on the right side of the blue bar at the bottom of every page ?>
<?cs def:custom_buildinfo() ?>Build <?cs var:page.build ?> - <?cs var:page.now ?><?cs /def ?>

<?cs def:list(label, classes) ?>
  <?cs if:subcount(classes) ?>
    <h2><?cs var:label ?></h2>
    <ul>
    <?cs each:cl=classes ?>
        <li><?cs call:type_link(cl) ?></li>
    <?cs /each ?>
    </ul>
  <?cs /if ?>
<?cs /def ?>

<?cs def:custom_left_nav() ?>
<?cs /def ?>


<?cs def:devdoc_left_nav() ?>
<?cs /def ?>
