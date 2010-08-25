<?cs def:custom_left_nav() ?>
  <?cs if:doc.hidenav != "true" ?>
    <?cs if:doc.type == "source" ?>
      <?cs call:source_nav() ?>
    <?cs elif:doc.type == "porting" ?>
      <?cs call:porting_nav() ?>
    <?cs elif:doc.type == "compatibility" ?>
      <?cs call:compatibility_nav() ?>
    <?cs elif:doc.type == "community" ?>
      <?cs call:community_nav() ?>
    <?cs elif:doc.type == "about" ?>
      <?cs call:about_nav() ?>
    <?cs /if ?>
  <?cs /if ?>
<?cs /def ?>
