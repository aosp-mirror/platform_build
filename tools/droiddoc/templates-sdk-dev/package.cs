<?cs # THIS CREATES A PACKAGE SUMMARY PAGE FROM EACH package.html FILES
     # AND NAMES IT package-summary.html ?>
<?cs include:"macros.cs" ?>
<?cs include:"macros_override.cs" ?>
<?cs include:"doctype.cs" ?>
<html<?cs if:devsite ?> devsite<?cs /if ?>>
<?cs include:"head_tag.cs" ?>
<?cs include:"body_tag.cs" ?>
<?cs include:"header.cs" ?>
<?cs include:"page_info.cs" ?>
<div class="api apilevel-<?cs var:package.since ?>" id="jd-content">

<h1><?cs var:package.name ?></h1>

<?cs if:subcount(package.descr) ?>
  <?cs call:tag_list(package.descr) ?>
<?cs /if ?>

<?cs def:class_table(label, classes) ?>
  <?cs if:subcount(classes) ?>
    <h2><?cs var:label ?></h2>
    <?cs call:class_link_table(classes) ?>
  <?cs /if ?>
<?cs /def ?>

<?cs call:class_table("Annotations", package.annotations) ?>
<?cs call:class_table("Interfaces", package.interfaces) ?>
<?cs call:class_table("Classes", package.classes) ?>
<?cs call:class_table("Enums", package.enums) ?>
<?cs call:class_table("Exceptions", package.exceptions) ?>
<?cs call:class_table("Errors", package.errors) ?>

</div><!-- end apilevel -->

<?cs if:devsite ?>
<div class="data-reference-resources-wrapper">
  <?cs if:subcount(class.package) ?>
  <ul data-reference-resources>
    <?cs call:list("Annotations", class.package.annotations) ?>
    <?cs call:list("Interfaces", class.package.interfaces) ?>
    <?cs call:list("Classes", class.package.classes) ?>
    <?cs call:list("Enums", class.package.enums) ?>
    <?cs call:list("Exceptions", class.package.exceptions) ?>
    <?cs call:list("Errors", class.package.errors) ?>
  </ul>
  <?cs elif:subcount(package) ?>
  <ul data-reference-resources>
    <?cs call:class_link_list("Annotations", package.annotations) ?>
    <?cs call:class_link_list("Interfaces", package.interfaces) ?>
    <?cs call:class_link_list("Classes", package.classes) ?>
    <?cs call:class_link_list("Enums", package.enums) ?>
    <?cs call:class_link_list("Exceptions", package.exceptions) ?>
    <?cs call:class_link_list("Errors", package.errors) ?>
  </ul>
  <?cs /if ?>
</div>
<?cs /if ?>

<?cs if:!devsite ?>
<?cs include:"footer.cs" ?>
<?cs include:"trailer.cs" ?>
<?cs /if ?>
</body>
</html>
