<?cs # THIS CREATES A CLASS OR INTERFACE PAGE FROM .java FILES ?>
<?cs include:"macros.cs" ?>
<?cs include:"macros_override.cs" ?>
<?cs
####################
# MACRO FUNCTION USED ONLY IN THIS TEMPLATE TO GENERATE API REFERENCE
# FIRST, THE FUNCTIONS FOR THE SUMMARY AT THE TOP OF THE PAGE
####################
?>

<?cs
# Prints the table cells for the summary of methods.
?><?cs def:write_method_summary(methods, included) ?>
<?cs set:count = #1 ?>
<?cs each:method = methods ?>
  <?cs # The apilevel-N class MUST BE LAST in the sequence of class names ?>
  <tr class="api apilevel-<?cs var:method.since ?>" >
  <?cs # leave out this cell if there is no return type = if constructors ?>
  <?cs if:subcount(method.returnType) ?>
    <td><code>
        <?cs var:method.abstract ?>
        <?cs var:method.default ?>
        <?cs var:method.static ?>
        <?cs var:method.final ?>
        <?cs call:type_link(method.generic) ?>
        <?cs call:type_link(method.returnType) ?></code>
    </td>
  <?cs /if ?>
    <td width="100%">
      <code>
      <?cs call:cond_link(method.name, toroot, method.href, included) ?>(<?cs call:parameter_list(method.params, 0) ?>)
      </code>
      <?cs if:subcount(method.shortDescr) || subcount(method.deprecated) ?>
        <p><?cs call:short_descr(method) ?>
        <?cs call:show_annotations_list(method) ?></p>
      <?cs /if ?>
    </td>
  </tr>
  <?cs set:count = count + #1 ?>
<?cs /each ?>
<?cs /def ?>

<?cs
# Print the table cells for the summary of fields.
?><?cs def:write_field_summary(fields, included) ?>
<?cs set:count = #1 ?>
<?cs each:field=fields ?>
  <tr class="api apilevel-<?cs var:field.since ?>" >
    <td><code>
    <?cs var:field.scope ?>
    <?cs var:field.static ?>
    <?cs var:field.final ?>
    <?cs call:type_link(field.type) ?></code></td>
    <td width="100%">
      <code><?cs call:cond_link(field.name, toroot, field.href, included) ?></code>
      <p><?cs call:short_descr(field) ?>
      <?cs call:show_annotations_list(field) ?></p>
    </td>
  </tr>
  <?cs set:count = count + #1 ?>
<?cs /each ?>
<?cs /def ?>

<?cs
# Print the table cells for the summary of constants
?><?cs def:write_constant_summary(fields, included) ?>
<?cs set:count = #1 ?>
    <?cs each:field=fields ?>
    <tr class="api apilevel-<?cs var:field.since ?>" >
        <td><code><?cs call:type_link(field.type) ?></code></td>
        <td width="100%">
          <code><?cs call:cond_link(field.name, toroot, field.href, included) ?></code>
          <p><?cs call:short_descr(field) ?>
          <?cs call:show_annotations_list(field) ?></p>
        </td>
    </tr>
    <?cs set:count = count + #1 ?>
    <?cs /each ?>
<?cs /def ?>

<?cs
# Print the table cells for the summary of attributes
?><?cs def:write_attr_summary(attrs, included) ?>
<?cs set:count = #1 ?>
    <?cs each:attr=attrs ?>
    <tr class="api apilevel-<?cs var:attr.since ?>" >
        <td><?cs if:included ?><a href="<?cs var:toroot ?><?cs var:attr.href ?>"><?cs /if
          ?><code><?cs var:attr.name ?></code><?cs if:included ?></a><?cs /if ?></td>
        <td width="100%">
          <?cs call:short_descr(attr) ?>&nbsp;
          <?cs call:show_annotations_list(attr) ?>
        </td>
    </tr>
    <?cs set:count = count + #1 ?>
    <?cs /each ?>
<?cs /def ?>

<?cs
# Print the table cells for the inner classes
?><?cs def:write_inners_summary(classes) ?>
<?cs set:count = #1 ?>
  <?cs each:cl=class.inners ?>
    <tr class="api apilevel-<?cs var:cl.since ?>" >
      <td class="jd-typecol"><code>
        <?cs var:cl.scope ?>
        <?cs var:cl.static ?>
        <?cs var:cl.final ?>
        <?cs var:cl.abstract ?>
        <?cs var:cl.kind ?></code></td>
      <td class="jd-descrcol" width="100%">
        <code><?cs call:type_link(cl.type) ?></code>
        <p><?cs call:short_descr(cl) ?>&nbsp;
        <?cs call:show_annotations_list(cl) ?></p>
      </td>
    </tr>
    <?cs set:count = count + #1 ?>
    <?cs /each ?>
<?cs /def ?>
<?cs
###################
# END OF FUNCTIONS FOR API SUMMARY
# START OF FUNCTIONS FOR THE API DETAILS
###################
?>
<?cs
# Print the table cells for the summary of constants
?>
<?cs def:write_field_details(fields) ?>
<?cs each:field=fields ?>
<?cs # this next line must be exactly like this to be parsed by eclipse ?>
<?cs # the A tag in the next line must remain where it is, so that Eclipse can parse the docs ?>
<A NAME="<?cs var:field.anchor ?>"></A>
<?cs # The apilevel-N class MUST BE LAST in the sequence of class names ?>
<div class="api apilevel-<?cs var:field.since ?>">
    <h3 class="api-name"><?cs var:field.name ?></h3>
    <div class="api-level">
      <?cs call:since_tags(field) ?>
      <?cs call:federated_refs(field) ?>
    </div>
<pre class="api-signature no-pretty-print">
<?cs if:subcount(field.scope) ?><?cs var:field.scope
?> <?cs /if ?><?cs if:subcount(field.static) ?><?cs var:field.static
?> <?cs /if ?><?cs if:subcount(field.final) ?><?cs var:field.final
?> <?cs /if ?><?cs if:subcount(field.type) ?><?cs call:type_link(field.type)
?> <?cs /if ?><?cs var:field.name ?></pre>
    <?cs call:show_annotations_list(field) ?>
    <?cs call:description(field) ?>
    <?cs if:subcount(field.constantValue) ?>
      <p>Constant Value:
      <?cs if:field.constantValue.isString ?>
          <?cs var:field.constantValue.str ?>
      <?cs else ?>
          <?cs var:field.constantValue.dec ?>
          (<?cs var:field.constantValue.hex ?>)
      <?cs /if ?>
    <?cs /if ?>
</div>
<?cs /each ?>
<?cs /def ?>

<?cs def:write_method_details(methods) ?>
<?cs each:method=methods ?>
<?cs # the A tag in the next line must remain where it is, so that Eclipse can parse the docs ?>
<A NAME="<?cs var:method.anchor ?>"></A>
<?cs # The apilevel-N class MUST BE LAST in the sequence of class names ?>
<div class="api apilevel-<?cs var:method.since ?>">
    <h3 class="api-name"><?cs var:method.name ?></h3>
    <div class="api-level">
      <div><?cs call:since_tags(method) ?></div>
      <?cs call:federated_refs(method) ?>
    </div>
<pre class="api-signature no-pretty-print">
<?cs if:subcount(method.scope) ?><?cs var:method.scope
?> <?cs /if ?><?cs if:subcount(method.static) ?><?cs var:method.static
?> <?cs /if ?><?cs if:subcount(method.final) ?><?cs var:method.final
?> <?cs /if ?><?cs if:subcount(method.abstract) ?><?cs var:method.abstract
?> <?cs /if ?><?cs if:subcount(method.returnType) ?><?cs call:type_link(method.returnType)
?> <?cs /if ?><?cs var:method.name ?> (<?cs call:parameter_list(method.params, 1) ?>)</pre>
    <?cs call:show_annotations_list(method) ?>
    <?cs call:description(method) ?>
</div>
<?cs /each ?>
<?cs /def ?>

<?cs def:write_attr_details(attrs) ?>
<?cs each:attr=attrs ?>
<?cs # the A tag in the next line must remain where it is, so that Eclipse can parse the docs ?>
<A NAME="<?cs var:attr.anchor ?>"></A>
<h3 class="api-name"><?cs var:attr.name ?></h3>
<?cs call:show_annotations_list(attr) ?>
<?cs call:description(attr) ?>
<?cs if:subcount(attr.methods) ?>
  <p><b>Related methods:</b></p>
  <ul class="nolist">
  <?cs each:m=attr.methods ?>
    <li><a href="<?cs var:toroot ?><?cs var:m.href ?>"><?cs var:m.name ?></a></li>
  <?cs /each ?>
  </ul>
<?cs /if ?>
<?cs /each ?>
<?cs /def ?>
<?cs
#########################
# END OF MACROS
# START OF PAGE PRINTING
#########################
?>
<?cs include:"doctype.cs" ?>
<html<?cs if:devsite ?> devsite<?cs /if ?>>
<?cs include:"head_tag.cs" ?>
<?cs include:"body_tag.cs" ?>
<?cs include:"header.cs" ?>
<?cs include:"page_info.cs" ?>
<?cs # This DIV spans the entire document to provide scope for some scripts ?>
<div class="api apilevel-<?cs var:class.since ?>" id="jd-content">
<?cs # this next line must be exactly like this to be parsed by eclipse ?>
<!-- ======== START OF CLASS DATA ======== -->
<?cs
#
# Page header with class name and signature
#
?>
<h1 class="api-title"><?cs var:class.name ?></h1>
<p>
<code class="api-signature">
  <?cs var:class.scope ?>
  <?cs var:class.static ?>
  <?cs var:class.final ?>
  <?cs var:class.abstract ?>
  <?cs var:class.kind ?>
  <?cs var:class.name ?>
</code>
<br>
<?cs set:colspan = subcount(class.inheritance) ?>
<?cs each:supr = class.inheritance ?>
<code class="api-signature">
  <?cs if:colspan == 2 ?>
    extends <?cs call:type_link(supr.short_class) ?>
  <?cs /if ?>
  <?cs if:last(supr) && subcount(supr.interfaces) ?>
      implements
      <?cs each:t=supr.interfaces ?>
        <?cs call:type_link(t) ?><?cs
          if: name(t)!=subcount(supr.interfaces)-1
            ?>, <?cs /if ?>
      <?cs /each ?>
  <?cs /if ?>
  <?cs set:colspan = colspan-1 ?>
</code>
<?cs /each ?>
</p><?cs
#
# Class inheritance tree
#
?><table class="jd-inheritance-table">
<?cs set:colspan = subcount(class.inheritance) ?>
<?cs each:supr = class.inheritance ?>
  <tr>
    <?cs loop:i = 1, (subcount(class.inheritance)-colspan), 1 ?>
      <td class="jd-inheritance-space">&nbsp;<?cs
        if:(subcount(class.inheritance)-colspan) == i
          ?>&nbsp;&nbsp;&#x21b3;<?cs
        /if ?></td>
    <?cs /loop ?>
    <td colspan="<?cs var:colspan ?>" class="jd-inheritance-class-cell"><?cs
      if:colspan == 1
          ?><?cs call:class_name(class.qualifiedType) ?><?cs
      else
          ?><?cs call:type_link(supr.class) ?><?cs
      /if ?>
    </td>
  </tr>
  <?cs set:colspan = colspan-1 ?>
<?cs /each ?>
</table><?cs
#
# Collapsible list of subclasses
#
?><?cs
if:subcount(class.subclasses.direct) && !class.subclasses.hidden ?>
  <table class="jd-sumtable jd-sumtable-subclasses">
  <tr><td style="border:none;margin:0;padding:0;">
    <?cs call:expando_trigger("subclasses-direct", "closed") ?>Known Direct Subclasses
    <?cs call:expandable_class_list("subclasses-direct", class.subclasses.direct, "list") ?>
  </td></tr>
  </table>
  <?cs /if ?>
  <?cs if:subcount(class.subclasses.indirect) && !class.subclasses.hidden ?>
  <table class="jd-sumtable jd-sumtable-subclasses"><tr><td colspan="2" style="border:none;margin:0;padding:0;">
  <?cs call:expando_trigger("subclasses-indirect", "closed") ?>Known Indirect Subclasses
  <?cs call:expandable_class_list("subclasses-indirect", class.subclasses.indirect, "list") ?>
  </td></tr></table><?cs
/if ?>
<?cs call:show_annotations_list(class) ?>
<br><hr><?cs
#
# The long-form class description.
#
?><?cs call:deprecated_warning(class) ?>

<?cs if:subcount(class.descr) ?>
  <p><?cs call:tag_list(class.descr) ?></p>
<?cs /if ?>

<?cs call:see_also_tags(class.seeAlso) ?>
<?cs
#################
# CLASS SUMMARY
#################
?>
<?cs # make sure there is a summary view to display ?>
<?cs if:subcount(class.inners)
     || subcount(class.attrs)
     || inhattrs
     || subcount(class.enumConstants)
     || subcount(class.constants)
     || inhconstants
     || subcount(class.fields)
     || inhfields
     || subcount(class.ctors.public)
     || subcount(class.ctors.protected)
     || subcount(class.methods.public)
     || subcount(class.methods.protected)
     || inhmethods ?>
<h2 class="api-section">Summary</h2>

<?cs if:subcount(class.inners) ?>
<?cs # this next line must be exactly like this to be parsed by eclipse ?>
<!-- ======== NESTED CLASS SUMMARY ======== -->
<table id="nestedclasses" class="responsive">
<tr><th colspan="2"><h3>Nested classes</h3></th></tr>
<?cs call:write_inners_summary(class.inners) ?>
<?cs /if ?>

<?cs # this next line must be exactly like this to be parsed by eclipse ?>
<?cs if:subcount(class.attrs) ?>
<!-- =========== FIELD SUMMARY =========== -->
<table id="lattrs" class="responsive">
<tr><th colspan="2"><h3>XML attributes</h3></th></tr>
<?cs call:write_attr_summary(class.attrs, 1) ?>
<?cs /if ?>

<?cs # if there are inherited attrs, write the table ?>
<?cs if:inhattrs ?>
<?cs # this next line must be exactly like this to be parsed by eclipse ?>
<!-- =========== FIELD SUMMARY =========== -->
<table id="inhattrs" class="responsive inhtable">
<tr><th><h3>Inherited XML attributes</h3></th></tr>
<?cs each:cl=class.inherited ?>
<?cs if:subcount(cl.attrs) ?>
<tr class="api apilevel-<?cs var:cl.since ?>" >
<td colspan="2">
<?cs call:expando_trigger("inherited-attrs-"+cl.qualified, "closed") ?>From
<?cs var:cl.kind ?>
<code>
  <?cs call:cond_link(cl.qualified, toroot, cl.link, cl.included) ?>
</code>
<div id="inherited-attrs-<?cs var:cl.qualified ?>">
  <div id="inherited-attrs-<?cs var:cl.qualified ?>-list"
        class="jd-inheritedlinks">
  </div>
  <div id="inherited-attrs-<?cs var:cl.qualified ?>-summary" style="display: none;">
    <table class="jd-sumtable-expando">
    <?cs call:write_attr_summary(cl.attrs, cl.included) ?></table>
  </div>
</div>
</td></tr>
<?cs /if ?>
<?cs /each ?>
</table>
<?cs /if ?>

<?cs if:subcount(class.enumConstants) ?>
<?cs # this next line must be exactly like this to be parsed by eclipse ?>
<!-- =========== ENUM CONSTANT SUMMARY =========== -->
<table id="enumconstants" class="responsive constants">
  <tr><th colspan="2"><h3>Enum values</h3></th></tr>
<?cs set:count = #1 ?>
  <?cs each:field=class.enumConstants ?>
  <tr class="api apilevel-<?cs var:field.since ?>" >
    <td><code><?cs call:type_link(field.type) ?></code>&nbsp;</td>
    <td width="100%">
      <code><?cs call:cond_link(field.name, toroot, field.href, cl.included) ?></code>
      <p><?cs call:short_descr(field) ?>&nbsp;
      <?cs call:show_annotations_list(field) ?></p>
    </td>
  </tr>
  <?cs set:count = count + #1 ?>
  <?cs /each ?>
<?cs /if ?>

<?cs if:subcount(class.constants) ?>
<?cs # this next line must be exactly like this to be parsed by eclipse ?>
<!-- =========== ENUM CONSTANT SUMMARY =========== -->
<table id="constants" class="responsive constants">
<tr><th colspan="2"><h3>Constants</h3></th></tr>
<?cs call:write_constant_summary(class.constants, 1) ?>
</table>
<?cs /if ?>

<?cs # if there are inherited constants, write the table ?>
<?cs if:inhconstants ?>
<?cs # this next line must be exactly like this to be parsed by eclipse ?>
<!-- =========== ENUM CONSTANT SUMMARY =========== -->
<table id="inhconstants" class="responsive constants inhtable">
<tr><th><h3>Inherited constants</h3></th></tr>
<?cs each:cl=class.inherited ?>
<?cs if:subcount(cl.constants) ?>
  <tr class="api apilevel-<?cs var:cl.since ?>" >
  <td>
  <?cs call:expando_trigger("inherited-constants-"+cl.qualified, "closed") ?>From
  <?cs var:cl.kind ?>
  <code>
    <?cs call:cond_link(cl.qualified, toroot, cl.link, cl.included) ?>
  </code>
  <div id="inherited-constants-<?cs var:cl.qualified ?>">
    <div id="inherited-constants-<?cs var:cl.qualified ?>-list"
          class="jd-inheritedlinks">
    </div>
    <div id="inherited-constants-<?cs var:cl.qualified ?>-summary" style="display: none;">
      <table class="jd-sumtable-expando responsive">
      <?cs call:write_constant_summary(cl.constants, cl.included) ?></table>
    </div>
  </div>
  </td></tr>
<?cs /if ?>
<?cs /each ?>
</table>
<?cs /if ?>

<?cs if:subcount(class.fields) ?>
<?cs # this next line must be exactly like this to be parsed by eclipse ?>
<!-- =========== FIELD SUMMARY =========== -->
<table id="lfields" class="responsive properties">
<tr><th colspan="2"><h3>Fields</h3></th></tr>
<?cs call:write_field_summary(class.fields, 1) ?>
</table>
<?cs /if ?>

<?cs # if there are inherited fields, write the table ?>
<?cs if:inhfields ?>
<?cs # this next line must be exactly like this to be parsed by eclipse ?>
<!-- =========== FIELD SUMMARY =========== -->
<table id="inhfields" class="properties inhtable">
<tr><th><h3>Inherited fields</h3></th></tr>
<?cs each:cl=class.inherited ?>
<?cs if:subcount(cl.fields) ?>
  <tr class="api apilevel-<?cs var:cl.since ?>" >
  <td>
  <?cs call:expando_trigger("inherited-fields-"+cl.qualified, "closed") ?>From
  <?cs var:cl.kind ?>
  <code>
    <?cs call:cond_link(cl.qualified, toroot, cl.link, cl.included) ?>
  </code>
  <div id="inherited-fields-<?cs var:cl.qualified ?>">
    <div id="inherited-fields-<?cs var:cl.qualified ?>-list"
          class="jd-inheritedlinks">
    </div>
    <div id="inherited-fields-<?cs var:cl.qualified ?>-summary" style="display: none;">
      <table class="jd-sumtable-expando responsive">
      <?cs call:write_field_summary(cl.fields, cl.included) ?></table>
    </div>
  </div>
  </td></tr>
<?cs /if ?>
<?cs /each ?>
</table>
<?cs /if ?>

<?cs if:subcount(class.ctors.public) ?>
<?cs # this next line must be exactly like this to be parsed by eclipse ?>
<!-- ======== CONSTRUCTOR SUMMARY ======== -->
<table id="pubctors" class="responsive constructors">
<tr><th colspan="2"><h3>Public constructors</h3></th></tr>
<?cs call:write_method_summary(class.ctors.public, 1) ?>
</table>
<?cs /if ?>

<?cs if:subcount(class.ctors.protected) ?>
<?cs # this next line must be exactly like this to be parsed by eclipse ?>
<!-- ======== CONSTRUCTOR SUMMARY ======== -->
<table id="proctors" class="responsive constructors">
<tr><th colspan="2"><h3>Protected constructors</h3></th></tr>
<?cs call:write_method_summary(class.ctors.protected, 1) ?>
</table>
<?cs /if ?>

<?cs if:subcount(class.methods.public) ?>
<?cs # this next line must be exactly like this to be parsed by eclipse ?>
<!-- ========== METHOD SUMMARY =========== -->
<table id="pubmethods" class="responsive methods">
<tr><th colspan="2"><h3>Public methods</h3></th></tr>
<?cs call:write_method_summary(class.methods.public, 1) ?>
</table>
<?cs /if ?>

<?cs if:subcount(class.methods.protected) ?>
<?cs # this next line must be exactly like this to be parsed by eclipse ?>
<!-- ========== METHOD SUMMARY =========== -->
<table id="promethods" class="reponsive methods">
<tr><th colspan="2"><h3>Protected methods</h3></th></tr>
<?cs call:write_method_summary(class.methods.protected, 1) ?>
</table>
<?cs /if ?>

<?cs # if there are inherited methods, write the table ?>
<?cs if:inhmethods ?>
<?cs # this next line must be exactly like this to be parsed by eclipse ?>
<!-- ========== METHOD SUMMARY =========== -->
<table id="inhmethods" class="methods inhtable">
<tr><th><h3>Inherited methods</h3></th></tr>
<?cs each:cl=class.inherited ?>
<?cs if:subcount(cl.methods) ?>
<tr class="api apilevel-<?cs var:cl.since ?>" >
<td colspan="2">
<?cs call:expando_trigger("inherited-methods-"+cl.qualified, "closed") ?>From
<?cs var:cl.kind ?>
<code>
  <?cs if:cl.included ?>
    <a href="<?cs var:toroot ?><?cs var:cl.link ?>"><?cs var:cl.qualified ?></a>
  <?cs elif:cl.federated ?>
    <a href="<?cs var:cl.link ?>"><?cs var:cl.qualified ?></a>
  <?cs else ?>
    <?cs var:cl.qualified ?>
  <?cs /if ?>
</code>
<div id="inherited-methods-<?cs var:cl.qualified ?>">
  <div id="inherited-methods-<?cs var:cl.qualified ?>-list"
        class="jd-inheritedlinks">
  </div>
  <div id="inherited-methods-<?cs var:cl.qualified ?>-summary" style="display: none;">
    <table class="jd-sumtable-expando responsive">
      <?cs call:write_method_summary(cl.methods, cl.included) ?>
    </table>
  </div>
</div>
</td></tr>
<?cs /if ?>
<?cs /each ?>
</table>
<?cs /if ?>
<?cs /if ?>
<?cs
################
# CLASS DETAILS
################
?>
<!-- XML Attributes -->
<?cs if:subcount(class.attrs) ?>
<?cs # this next line must be exactly like this to be parsed by eclipse ?>
<!-- ========= FIELD DETAIL ======== -->
<h2 class="api-section">XML attributes</h2>
<?cs call:write_attr_details(class.attrs) ?>
<?cs /if ?>

<!-- Enum Values -->
<?cs if:subcount(class.enumConstants) ?>
<?cs # this next line must be exactly like this to be parsed by eclipse ?>
<!-- ========= ENUM CONSTANTS DETAIL ======== -->
<h2 class="api-section">Enum values</h2>
<?cs call:write_field_details(class.enumConstants) ?>
<?cs /if ?>

<!-- Constants -->
<?cs if:subcount(class.constants) ?>
<?cs # this next line must be exactly like this to be parsed by eclipse ?>
<!-- ========= ENUM CONSTANTS DETAIL ======== -->
<h2 class="api-section">Constants</h2>
<?cs call:write_field_details(class.constants) ?>
<?cs /if ?>

<!-- Fields -->
<?cs if:subcount(class.fields) ?>
<?cs # this next line must be exactly like this to be parsed by eclipse ?>
<!-- ========= FIELD DETAIL ======== -->
<h2 class="api-section">Fields</h2>
<?cs call:write_field_details(class.fields) ?>
<?cs /if ?>

<!-- Public ctors -->
<?cs if:subcount(class.ctors.public) ?>
<?cs # this next line must be exactly like this to be parsed by eclipse ?>
<!-- ========= CONSTRUCTOR DETAIL ======== -->
<h2 class="api-section">Public constructors</h2>
<?cs call:write_method_details(class.ctors.public) ?>
<?cs /if ?>

<?cs # this next line must be exactly like this to be parsed by eclipse ?>
<!-- ========= CONSTRUCTOR DETAIL ======== -->
<!-- Protected ctors -->
<?cs if:subcount(class.ctors.protected) ?>
<h2 class="api-section">Protected constructors</h2>
<?cs call:write_method_details(class.ctors.protected) ?>
<?cs /if ?>

<?cs # this next line must be exactly like this to be parsed by eclipse ?>
<!-- ========= METHOD DETAIL ======== -->
<!-- Public methdos -->
<?cs if:subcount(class.methods.public) ?>
<h2 class="api-section">Public methods</h2>
<?cs call:write_method_details(class.methods.public) ?>
<?cs /if ?>

<?cs # this next line must be exactly like this to be parsed by eclipse ?>
<!-- ========= METHOD DETAIL ======== -->
<?cs if:subcount(class.methods.protected) ?>
<h2 class="api-section">Protected methods</h2>
<?cs call:write_method_details(class.methods.protected) ?>
<?cs /if ?>

<?cs # the next two lines must be exactly like this to be parsed by eclipse ?>
<!-- ========= END OF CLASS DATA ========= -->

</div><!-- end jd-content -->

<?cs if:devsite ?>

<div class="data-reference-resources-wrapper">
  <?cs if:subcount(class.package) ?>
  <ul data-reference-resources>
    <?cs call:list("Annotations", class.package.annotations) ?>
    <?cs call:list("Interfaces", class.package.interfaces) ?>
    <?cs call:list("Classes", class.package.classes) ?>
    <?cs call:list("Enums", class.package.enums) ?>
    <?cs call:list("Exceptions", class.package.exceptions) ?>
    <?cs call:list("Errors", class.package.errors) ?>
  </ul>
  <?cs elif:subcount(package) ?>
  <ul data-reference-resources>
    <?cs call:class_link_list("Annotations", package.annotations) ?>
    <?cs call:class_link_list("Interfaces", package.interfaces) ?>
    <?cs call:class_link_list("Classes", package.classes) ?>
    <?cs call:class_link_list("Enums", package.enums) ?>
    <?cs call:class_link_list("Exceptions", package.exceptions) ?>
    <?cs call:class_link_list("Errors", package.errors) ?>
  </ul>
  <?cs /if ?>
</div>
<?cs /if ?>

<?cs if:!devsite ?>
<?cs include:"footer.cs" ?>
<?cs include:"trailer.cs" ?>
<?cs /if ?>
</body>
</html>
