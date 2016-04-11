<?cs # THIS CREATES A LIST OF ALL PACKAGES AND NAMES IT packages.html ?>
<?cs include:"macros.cs" ?>
<?cs include:"doctype.cs" ?>
<html<?cs if:devsite ?> devsite<?cs /if ?>>
<?cs include:"head_tag.cs" ?>
<?cs include:"body_tag.cs" ?>
<?cs include:"header.cs" ?>

<h1><?cs var:page.title ?></h1>
<p>These are the API packages.
See all <a href="classes.html">API classes</a>.</p>

<?cs set:count = #1 ?>
<table>
<?cs each:pkg = docs.packages ?>
    <tr class="api apilevel-<?cs var:pkg.since ?>" >
        <td class="jd-linkcol"><?cs call:package_link(pkg) ?></td>
        <td class="jd-descrcol" width="100%"><?cs call:tag_list(pkg.shortDescr) ?></td>
    </tr>
<?cs set:count = count + #1 ?>
<?cs /each ?>
</table>

<?cs if:!devsite ?>
<?cs include:"footer.cs" ?>
<?cs include:"trailer.cs" ?>
<?cs /if ?>
</body>
</html>
