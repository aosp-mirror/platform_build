<?cs

# print out the yaml nav for the reference docs, only printing the title,
path, and status_text (API level) for each package.

?>
reference:<?cs
each:page = docs.pages?><?cs
  if:page.type == "package"?>
- title: <?cs var:page.label ?>
  path: /<?cs var:page.link ?>
  status_text: apilevel-<?cs var:page.apilevel ?><?cs
  /if?><?cs
/each ?>
