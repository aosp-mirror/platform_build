var <?cs
  if:reference.testSupport ?>SUPPORT_TEST_<?cs
  elif: reference.wearableSupport ?>SUPPORT_WEARABLE_<?cs 
  /if ?>DATA = [
<?cs each:page = docs.pages
?>      { id:<?cs var: page.id ?>, label:"<?cs var:page.label ?>", link:"<?cs var:page.link ?>", type:"<?cs var:page.type ?>", deprecated:"<?cs var:page.deprecated ?>" }<?cs if:!last(page) ?>,<?cs /if ?>
<?cs /each ?>
    ];
