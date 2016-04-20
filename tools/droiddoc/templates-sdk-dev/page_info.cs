<?cs # optional, more info about the page, such as API level and links ?>
<?cs
# A modal dialog when API level is set too low for this page
?><div id="naMessage"></div>
<?cs
#
# If this is a package summary page...
#
?><?cs
if:subcount(package)
?>
<div id="api-info-block">
<div class="api-level">
  <?cs call:since_tags(package) ?>
  <?cs call:federated_refs(package) ?>
</div>
</div><?cs
#
# Or if this is a class page...
#
?><?cs
elif:subcount(class)
?>
<div id="api-info-block">
<div class="api-level">
  <?cs call:since_tags(class) ?><?cs
  if:class.deprecatedsince
    ?><br>Deprecated since <a href="<?cs var:toroot ?>guide/topics/manifest/uses-sdk-element.html#ApiLevels"
        >API level <?cs var:class.deprecatedsince ?></a><?cs
  /if ?>
  <?cs call:federated_refs(class) ?>
</div>

<?cs # Set variables about whether there are inherited members; no output ?>
<?cs each:cl=class.inherited ?>
  <?cs if:subcount(cl.methods) ?>
   <?cs set:inhmethods = #1 ?>
  <?cs /if ?>
  <?cs if:subcount(cl.constants) ?>
   <?cs set:inhconstants = #1 ?>
  <?cs /if ?>
  <?cs if:subcount(cl.fields) ?>
   <?cs set:inhfields = #1 ?>
  <?cs /if ?>
  <?cs if:subcount(cl.attrs) ?>
   <?cs set:inhattrs = #1 ?>
  <?cs /if ?>
<?cs /each ?>

<div class="sum-details-links">
<?cs if:inhattrs || inhconstants || inhfields || inhmethods || (!class.subclasses.hidden &&
     (subcount(class.subclasses.direct) || subcount(class.subclasses.indirect))) ?>
Summary:
<?cs if:subcount(class.inners) ?>
  <a href="#nestedclasses">Nested Classes</a>
  <?cs set:linkcount = #1 ?>
<?cs /if ?>
<?cs if:subcount(class.attrs) ?>
  <?cs if:linkcount ?>&#124; <?cs /if ?><a href="#lattrs">XML Attrs</a>
  <?cs set:linkcount = #1 ?>
<?cs /if ?>
<?cs if:inhattrs ?>
  <?cs if:linkcount ?>&#124; <?cs /if ?><a href="#inhattrs">Inherited XML Attrs</a>
  <?cs set:linkcount = #1 ?>
<?cs /if ?>
<?cs if:subcount(class.enumConstants) ?>
  <?cs if:linkcount ?>&#124; <?cs /if ?><a href="#enumconstants">Enums</a>
  <?cs set:linkcount = #1 ?>
<?cs /if ?>
<?cs if:subcount(class.constants) ?>
  <?cs if:linkcount ?>&#124; <?cs /if ?><a href="#constants">Constants</a>
  <?cs set:linkcount = #1 ?>
<?cs /if ?>
<?cs if:inhconstants ?>
  <?cs if:linkcount ?>&#124; <?cs /if ?><a href="#inhconstants">Inherited Constants</a>
  <?cs set:linkcount = #1 ?>
<?cs /if ?>
<?cs if:subcount(class.fields) ?>
  <?cs if:linkcount ?>&#124; <?cs /if ?><a href="#lfields">Fields</a>
  <?cs set:linkcount = #1 ?>
<?cs /if ?>
<?cs if:inhfields ?>
  <?cs if:linkcount ?>&#124; <?cs /if ?><a href="#inhfields">Inherited Fields</a>
  <?cs set:linkcount = #1 ?>
<?cs /if ?>
<?cs if:subcount(class.ctors.public) ?>
  <?cs if:linkcount ?>&#124; <?cs /if ?><a href="#pubctors">Ctors</a>
  <?cs set:linkcount = #1 ?>
<?cs /if ?>
<?cs if:subcount(class.ctors.protected) ?>
  <?cs if:linkcount ?>&#124; <?cs /if ?><a href="#proctors">Protected Ctors</a>
  <?cs set:linkcount = #1 ?>
<?cs /if ?>
<?cs if:subcount(class.methods.public) ?>
  <?cs if:linkcount ?>&#124; <?cs /if ?><a href="#pubmethods">Methods</a>
  <?cs set:linkcount = #1 ?>
<?cs /if ?>
<?cs if:subcount(class.methods.protected) ?>
  <?cs if:linkcount ?>&#124; <?cs /if ?><a href="#promethods">Protected Methods</a>
  <?cs set:linkcount = #1 ?>
<?cs /if ?>
<?cs if:inhmethods ?>
  <?cs if:linkcount ?>&#124; <?cs /if ?><a href="#inhmethods">Inherited Methods</a>
<?cs /if ?>
&#124; <a href="#" onclick="return toggleAllClassInherited()" id="toggleAllClassInherited">[Expand All]</a>
<?cs /if ?>
</div><!-- end sum-details-links -->
</div><!-- end api-info-block --><?cs
/if ?><?cs # end of if package or class ?>