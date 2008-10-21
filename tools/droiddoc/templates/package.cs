<?cs include:"macros.cs" ?>
<html>
<?cs include:"head_tag.cs" ?>
<?cs include:"header.cs" ?>

<div class="g-unit" id="doc-content">

<div id="jd-header">
  package
  <h1><?cs var:package.name ?></h1>

  <div class="jd-nav">
      <?cs if:subcount(package.shortDescr) ?>
      Classes |
      <a class="jd-navlink" href="package-descr.html">Description</a>
      <?cs /if ?>
  </div>
</div>

<div id="jd-content">

<?cs if:subcount(package.shortDescr) ?>
  <div class="jd-descr">
  <p><?cs call:tag_list(package.shortDescr) ?>
  <span class="jd-more"><a href="package-descr.html">more...</a></span></p>
  </div>
<?cs /if ?>

<?cs def:class_table(label, classes) ?>
  <?cs if:subcount(classes) ?>
    <h3><?cs var:label ?></h3>
    <?cs call:class_link_table(classes) ?>
  <?cs /if ?>
<?cs /def ?>

<?cs call:class_table("Interfaces", package.interfaces) ?>
<?cs call:class_table("Classes", package.classes) ?>
<?cs call:class_table("Enums", package.enums) ?>
<?cs call:class_table("Exceptions", package.exceptions) ?>
<?cs call:class_table("Errors", package.errors) ?>

<?cs include:"footer.cs" ?>
</div><!-- end jd-content -->
</div><!-- doc-content -->
<?cs include:"analytics.cs" ?>
</body>
</html>
