<a name="top"></a>
<?cs call:custom_masthead() ?>

<?cs if:guide ?>
  <?cs call:guide_nav() ?>
<?cs elif:publish ?>
  <?cs call:publish_nav() ?> 
<?cs elif:sdk ?>
  <?cs call:sdk_nav() ?>
<?cs else ?>
  <?cs call:custom_left_nav() ?> 
<?cs /if ?>
