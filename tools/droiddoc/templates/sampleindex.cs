<?cs include:"macros.cs" ?>
<?cs set:guide="true" ?>
<html>
<?cs include:"head_tag.cs" ?>
<?cs include:"header.cs" ?>

<div class="g-unit" id="doc-content">

<div id="jd-header">
<h1><?cs var:projectTitle ?></h1>
<?cs var:subdir ?>
</div>

<div id="jd-content">

<?cs var:summary ?>

<?cs if:subcount(subdirs) ?>
    <h2>Subdirectories</h2>
    <ul class="nolist">
    <?cs each:dir=subdirs ?>
      <li><a href="<?cs var:dir.name ?>/"><?cs var:dir.name ?>/</a></li>
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
<?cs include:"analytics.cs" ?>
</body>
</html>
