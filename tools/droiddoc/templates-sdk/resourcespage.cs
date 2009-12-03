<?cs include:"doctype.cs" ?>
<?cs include:"macros.cs" ?>

<html>
<?cs include:"head_tag.cs" ?>

<body class="gc-documentation">
<?cs call:custom_masthead() ?>
<?cs call:resources_tab_nav() ?>
<a name="top"></a>
<div class="g-unit" id="doc-content" >
  <div id="jd-header" class="guide-header">
    <span class="crumb">&nbsp;</span>
    <h1><?cs var:page.title ?></h1>
  </div>

  <div id="jd-content">

    <?cs call:tag_list(root.descr) ?>

<?cs include:"footer.cs" ?>

</div><!-- end doc-content -->

<?cs include:"trailer.cs" ?>

</body>
</html>



