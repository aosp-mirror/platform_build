<?cs include:"doctype.cs" ?>
<?cs include:"macros.cs" ?>
<?cs set:guide="true" ?>
<html>
<?cs include:"head_tag.cs" ?>
<?cs include:"header.cs" ?>

<div class="g-unit" id="doc-content"><a name="top"></a>

<div id="jd-header" class="guide-header">

  <span class="crumb">
    <a href="<?cs var:toroot ?>guide/samples/index.html">Sample Code &gt;</a>
    
  </span>
<h1><?cs var:page.title ?></h1>
</div>

<div id="jd-content">

<?cs var:summary ?>

<?cs if:subcount(subdirs) ?>
    <h2>Subdirectories</h2>
    <ul class="nolist">
    <?cs each:dir=subdirs ?>
      <li><a href="<?cs var:dir.name ?>/index.html"><?cs var:dir.name ?>/</a></li>
    <?cs /each ?>
    </ul>
<?cs /if ?>

<?cs if:subcount(files) ?>
    <h2>Files</h2>
    <ul class="nolist">
    <?cs each:file=files ?>
      <li><a href="<?cs var:file.href ?>"><?cs var:file.name ?></a></li>
    <?cs /each ?>
    </ul>
<?cs /if ?>

<?cs include:"footer.cs" ?>
</div><!-- end jd-content -->
</div><!-- end doc-content -->

<?cs include:"trailer.cs" ?>

</body>
</html>
