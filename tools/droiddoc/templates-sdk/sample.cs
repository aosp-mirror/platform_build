<?cs include:"doctype.cs" ?>
<?cs include:"macros.cs" ?>
<html<?cs if:devsite ?> devsite<?cs /if ?>>
<?cs include:"head_tag.cs" ?>
<body class="gc-documentation develop samples" itemscope itemtype="http://schema.org/Article">
<?cs include:"header.cs" ?>

<div <?cs if:fullpage
?>class="fullpage"<?cs elif:design||tools||about||sdk||distribute
?>class="col-13" id="doc-col"<?cs else 
?>class="col-12" id="doc-col"<?cs /if ?> >

<!-- start breadcrumb block -->
<div id="api-info-block">
  <div class="sum-details-links">

  <!-- related links -->
  <a href="<?cs var:toroot ?>samples/<?cs var:projectDir ?>/index.html">Overview</a>
  &#124; <a href="<?cs var:toroot ?>samples/<?cs var:projectDir ?>/project.html">Project</a>
  &#124; <a href="<?cs var:toroot ?>downloads/samples/<?cs var:projectDir ?>.zip">Download</a>

</div><!-- end sum-details-links -->

</div><!-- end breadcurmb block -->

<div id="jd-header" style="border:0;">

<div id="pathCrumb">
<?cs each:item = parentdirs ?>
  <?cs if:pathCrumbLinks
    ?><a href="<?cs var:toroot ?><?cs var:item.Link ?>"><?cs var:item.Name ?></a> / 
  <?cs else
    ?><?cs var:item.Name ?> / <?cs /if ?>
<?cs /each ?>
</div>

  <h1 itemprop="name"><?cs var:page.title ?></h1>
</div>
<!-- end breadcrumb block -->


<?cs # THIS IS THE MAIN DOC CONTENT ?>
<div id="jd-content">

<?cs if:android.whichdoc == "online" ?>

<?cs # If this is the online docs, build the src code navigation links ?>


<?cs var:summary ?>

<!-- begin file contents -->
<div id="codesample-wrapper">
<pre id="codesample-line-numbers" class="no-pretty-print hidden"></pre>
<pre id="codesample-block"><?cs var:fileContents ?></pre>
</div>

<!-- end file contents -->
<script type="text/javascript">
  initCodeLineNumbers();
</script>




<?cs else ?><?cs
  # else, this means it's offline docs,
          so don't show src links (we dont have the pages!) ?>

<?cs /if ?><?cs # end if/else online docs ?>

  </div> <!-- end jd-content -->

<?cs include:"footer.cs" ?>
</div><!-- end doc-content -->

<?cs include:"trailer.cs" ?>

</body>
</html>







