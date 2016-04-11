<?cs if:!devsite ?><?cs # leave out the global header for devsite; it is in devsite template ?>
  <?cs call:custom_masthead() ?>

  <?cs if:(fullpage) ?>
    <?cs call:fullpage() ?>
  <?cs else ?>
    <?cs call:body_content_wrap_start() ?>
  <?cs /if ?>

  <?cs call:search_results() ?>
<?cs /if ?><?cs # end if/else !devsite ?>
