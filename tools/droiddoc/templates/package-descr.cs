<?cs include:"macros.cs" ?>
<html>
<?cs include:"head_tag.cs" ?>
<?cs include:"header.cs" ?>

<div class="g-unit" id="doc-content">

<div id="jd-header">
  <strong>
    <div class="jd-page_title-prefix">package</div>
  </strong>
  <h1><?cs var:package.name ?></b></h1>
  <div class="jd-nav">
      <a class="jd-navlink" href="package-summary.html">Classes</a> |
      Description
  </div>
</div><!-- end header -->

<div id="jd-content">
<div class="jd-descr">
<p><?cs call:tag_list(package.descr) ?></p>
</div>

<?cs include:"footer.cs" ?>
</div><!-- end jd-content -->
</div> <!-- end doc-content -->
<?cs include:"analytics.cs" ?>
</body>
</html>
