<?cs # THIS CREATES A LIST OF ALL PACKAGES AND NAMES IT packages.html ?>
<?cs include:"macros.cs" ?>
<?cs include:"macros_override.cs" ?>
<?cs include:"doctype.cs" ?>
<html<?cs if:devsite ?> devsite<?cs /if ?>>
<?cs include:"head_tag.cs" ?>
<?cs include:"body_tag.cs" ?>
<?cs include:"header.cs" ?>

<h1><?cs var:page.title ?></h1>
<p>These are the API classes. See all
<a href="packages.html">API packages</a>.</p>

<div class="jd-letterlist"><?cs
  each:letter=docs.classes ?>
    <a href="#letter_<?cs name:letter ?>"><?cs
      name:letter ?></a>&nbsp;&nbsp;<?cs
  /each?>
</div>

<?cs each:letter=docs.classes ?>
<?cs set:count = #1 ?>
<h2 id="letter_<?cs name:letter ?>"><?cs name:letter ?></h2>
<table>
    <?cs set:cur_row = #0 ?>
    <?cs each:cl = letter ?>
        <tr class="<?cs if:count % #2 ?>alt-color<?cs /if ?> api apilevel-<?cs var:cl.since ?>" >
            <td class="jd-linkcol"><?cs call:type_link(cl.type) ?></td>
            <td class="jd-descrcol" width="100%">
              <?cs call:short_descr(cl) ?>&nbsp;
              <?cs call:show_annotations_list(cl) ?>
            </td>
        </tr>
    <?cs set:count = count + #1 ?>
    <?cs /each ?>
</table>
<?cs /each ?>

<?cs include:"footer.cs" ?>
<?cs include:"trailer.cs" ?>
</body>
</html>
