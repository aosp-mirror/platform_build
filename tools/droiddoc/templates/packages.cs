<?cs include:"macros.cs" ?>
<html>
<?cs include:"head_tag.cs" ?>
<?cs include:"header.cs" ?>

<div class="g-unit" id="doc-content">

<div id="jd-header">
<h1><?cs var:page.title ?></h1>
</div>

<div id="jd-content">

<div class="jd-descr">
<p><?cs call:tag_list(root.descr) ?></p>
</div>

<?cs set:count = #1 ?>
<table class="jd-linktable">
<?cs each:pkg = docs.packages ?>
    <tr class="jd-letterentries <?cs if:count % #2 ?>alt-color<?cs /if ?>" >
        <td class="jd-linkcol"><?cs call:package_link(pkg) ?></td>
        <td class="jd-descrcol" width="100%"><?cs call:tag_list(pkg.shortDescr) ?>&nbsp;</td>
    </tr>
<?cs set:count = count + #1 ?>
<?cs /each ?>
</table>

<?cs include:"footer.cs" ?>
</div><!-- end jd-content -->
</div> <!-- end doc-content -->
<?cs include:"analytics.cs" ?>
</body>
</html>
