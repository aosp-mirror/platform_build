<?cs include:"doctype.cs" ?>
<?cs include:"macros.cs" ?>
<?cs set:guide="true" ?>
<html>
<?cs include:"head_tag.cs" ?>
<?cs include:"header.cs" ?>

<div class="g-unit" id="doc-content">

<div id="jd-header">
<h1><?cs var:page.title ?></h1>
<?cs var:subdir ?>
</div>

<div id="jd-content">

<p><a href="<?cs var:realFile ?>">Original <?cs var:realFile ?></a></p>

<!-- begin file contents -->
<pre class="Code prettyprint"><?cs var:fileContents ?></pre>
<!-- end file contents -->

<?cs include:"footer.cs" ?>
</div><!-- end jd-content -->
</div> <!-- end doc-content -->

<?cs include:"trailer.cs" ?>

</body>
</html>
