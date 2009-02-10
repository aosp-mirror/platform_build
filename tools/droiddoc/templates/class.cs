<?cs include:"doctype.cs" ?>
<?cs include:"macros.cs" ?>
<html>
<?cs include:"head_tag.cs" ?>
<body>
<script type="text/javascript">
function toggleInherited(linkObj, expand) {
    var base = linkObj.getAttribute("id");
    var list = document.getElementById(base + "-list");
    var summary = document.getElementById(base + "-summary");
    var trigger = document.getElementById(base + "-trigger");
    var a = $(linkObj);
    if ( (expand == null && a.hasClass("closed")) || expand ) {
        list.style.display = "none";
        summary.style.display = "block";
        trigger.src = "<?cs var:toroot ?>assets/images/triangle-opened.png";
        a.removeClass("closed");
        a.addClass("opened");
    } else if ( (expand == null && a.hasClass("opened")) || (expand == false) ) {
        list.style.display = "block";
        summary.style.display = "none";
        trigger.src = "<?cs var:toroot ?>assets/images/triangle-closed.png";
        a.removeClass("opened");
        a.addClass("closed");
    }
    return false;
}
</script>

<?cs include:"header.cs" ?>

<div class="g-unit" id="doc-content">

<div id="api-info-block">

<?cs # are there inherited members ?>
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
</nobr>
<?cs if:inhattrs || inhconstants || inhfields || inhmethods || subcount(class.subclasses.direct) || subcount(class.subclasses.indirect) ?>
&#124; <a href="#" onclick="return toggleAllSummaryInherited(this)">[Expand All]</a>
<?cs /if ?>
</div>
</div>

<?cs # this next line must be exactly like this to be parsed by eclipse ?>
<!-- ======== START OF CLASS DATA ======== -->

<div id="jd-header">
    <?cs var:class.scope ?>
    <?cs var:class.static ?> 
    <?cs var:class.final ?> 
    <?cs var:class.abstract ?>
    <?cs var:class.kind ?>
<h1><?cs var:class.name ?></h1>

<?cs set:colspan = subcount(class.inheritance) ?>
<?cs each:supr = class.inheritance ?>
  <?cs if:colspan == 2 ?>
    extends <?cs call:type_link(supr.short_class) ?><br/>
  <?cs /if ?>
  <?cs if:last(supr) && subcount(supr.interfaces) ?>
      implements 
      <?cs each:t=supr.interfaces ?>
        <?cs call:type_link(t) ?> 
      <?cs /each ?>
  <?cs /if ?>
  <?cs set:colspan = colspan-1 ?>
<?cs /each ?>

</div><!-- end header -->


<div id="jd-content">
<table class="jd-inheritance-table">
<?cs set:colspan = subcount(class.inheritance) ?>
<?cs each:supr = class.inheritance ?>
    <tr>
        <?cs loop:i = 1, (subcount(class.inheritance)-colspan), 1 ?>
            <td class="jd-inheritance-space">&nbsp;<?cs if:(subcount(class.inheritance)-colspan) == i ?>&nbsp;&nbsp;&#x21b3;<?cs /if ?></td>
        <?cs /loop ?> 	
        <td colspan="<?cs var:colspan ?>" class="jd-inheritance-class-cell"><?cs
            if:colspan == 1
                ?><?cs call:class_name(class.qualifiedType) ?><?cs 
            else 
                ?><?cs call:type_link(supr.class) ?><?cs
            /if ?></td>
    </tr>
    <?cs set:colspan = colspan-1 ?>
<?cs /each ?>
</table>

<?cs # this next line must be exactly like this to be parsed by eclipse ?>
<!-- ======== NESTED CLASS SUMMARY ======== -->
<?cs if:subcount(class.subclasses.direct) ?>
<table class="jd-sumtable jd-sumtable-subclasses"><tr><td colspan="12" style="border:none;margin:0;padding:0;">
<?cs call:expando_trigger("subclasses-direct", "closed") ?>Known Direct Subclasses
<?cs call:expandable_class_list("subclasses-direct", class.subclasses.direct, "list") ?>
</td></tr></table>
<?cs /if ?>

<?cs if:subcount(class.subclasses.indirect) ?>
<table class="jd-sumtable jd-sumtable-subclasses"><tr><td colspan="12" style="border:none;margin:0;padding:0;">
<?cs call:expando_trigger("subclasses-indirect", "closed") ?>Known Indirect Subclasses
<?cs call:expandable_class_list("subclasses-indirect", class.subclasses.indirect, "list") ?>
</td></tr></table>
<?cs /if ?>

<div class="jd-descr">
<?cs call:deprecated_warning(class) ?>
<?cs if:subcount(class.descr) ?>
<h2>Class Overview</h2>
<p><?cs call:tag_list(class.descr) ?></p>
<?cs /if ?>

<?cs call:see_also_tags(class.seeAlso) ?>

</div><!-- jd-descr -->


<?cs # summary macros ?>

<?cs def:write_method_summary(methods) ?>
<?cs set:count = #1 ?>
<?cs each:method = methods ?>
    <tr <?cs if:count % #2 ?>class="alt-color"<?cs /if ?> >
        <td class="jd-typecol"><nobr>
            <?cs var:method.abstract ?>
            <?cs var:method.synchronized ?>
            <?cs var:method.final ?>
            <?cs var:method.static ?>
            <?cs call:type_link(method.generic) ?>
            <?cs call:type_link(method.returnType) ?></nobr>
        </td>
        <td class="jd-linkcol" width="100%"><nobr>
        <span class="sympad"><a href="<?cs var:toroot ?><?cs var:method.href ?>">
        <?cs var:method.name ?></a></span>(<?cs call:parameter_list(method.params) ?>)</nobr>
        <?cs if:subcount(method.shortDescr) || subcount(method.deprecated) ?>
        <div class="jd-descrdiv"><?cs call:short_descr(method) ?></div>
  <?cs /if ?>
  </td></tr>
<?cs set:count = count + #1 ?>
<?cs /each ?>
<?cs /def ?>

<?cs def:write_field_summary(fields) ?>
<?cs set:count = #1 ?>
    <?cs each:field=fields ?>
      <tr <?cs if:count % #2 ?>class="alt-color"<?cs /if ?> >
          <td class="jd-typecol"><nobr>
          <?cs var:field.scope ?>
          <?cs var:field.static ?>
          <?cs var:field.final ?>
          <?cs call:type_link(field.type) ?></nobr></td>
          <td class="jd-linkcol"><a href="<?cs var:toroot ?><?cs var:field.href ?>"><?cs var:field.name ?></a></td>
          <td class="jd-descrcol" width="100%"><?cs call:short_descr(field) ?></td>
      </tr>
      <?cs set:count = count + #1 ?>
    <?cs /each ?>
<?cs /def ?>

<?cs def:write_constant_summary(fields) ?>
<?cs set:count = #1 ?>
    <?cs each:field=fields ?>
    <tr <?cs if:count % #2 ?>class="alt-color"<?cs /if ?> >
        <td class="jd-typecol"><?cs call:type_link(field.type) ?></td>
        <td class="jd-linkcol"><a href="<?cs var:toroot ?><?cs var:field.href ?>"><?cs var:field.name ?></a></td>
        <td class="jd-descrcol" width="100%"><?cs call:short_descr(field) ?></td>
    </tr>
    <?cs set:count = count + #1 ?>
    <?cs /each ?>
<?cs /def ?>

<?cs def:write_attr_summary(attrs) ?>
<?cs set:count = #1 ?>
    <tr>
        <td><nobr><em>Attribute Name</em></nobr></td>
        <td><nobr><em>Related Method</em></nobr></td>
        <td><nobr><em>Description</em></nobr></td>
    </tr>
    <?cs each:attr=attrs ?>
    <tr <?cs if:count % #2 ?>class="alt-color"<?cs /if ?> >
        <td class="jd-linkcol"><a href="<?cs var:toroot ?><?cs var:attr.href ?>"><?cs var:attr.name ?></a></td>
        <td class="jd-linkcol"><?cs each:m=attr.methods ?>
            <a href="<?cs var:toroot ?><?cs var:m.href ?>"><?cs var:m.name ?></a>
            <?cs /each ?>
        </td>
        <td class="jd-descrcol" width="100%"><?cs call:short_descr(attr) ?>&nbsp;</td>
    </tr>
    <?cs set:count = count + #1 ?>
    <?cs /each ?>
<?cs /def ?>

<?cs def:write_inners_summary(classes) ?>
<?cs set:count = #1 ?>
  <?cs each:cl=class.inners ?>
    <tr <?cs if:count % #2 ?>class="alt-color"<?cs /if ?> >
      <td class="jd-typecol"><nobr>
        <?cs var:class.scope ?>
        <?cs var:class.static ?> 
        <?cs var:class.final ?> 
        <?cs var:class.abstract ?>
        <?cs var:class.kind ?></nobr></td>
      <td class="jd-linkcol"><?cs call:type_link(cl.type) ?></td>
      <td class="jd-descrcol" width="100%"><?cs call:short_descr(cl) ?>&nbsp;</td>
    </tr>
    <?cs set:count = count + #1 ?>
    <?cs /each ?>
<?cs /def ?>

<?cs # end macros ?>

<div class="jd-descr">
<h2>Summary</h2>

<?cs if:subcount(class.inners) ?>
<?cs # this next line must be exactly like this to be parsed by eclipse ?>
<!-- ======== NESTED CLASS SUMMARY ======== -->
<table id="nestedclasses" class="jd-sumtable"><tr><th colspan="12">Nested Classes</th></tr>
<?cs call:write_inners_summary(class.inners) ?>
<?cs /if ?>

<?cs # this next line must be exactly like this to be parsed by eclipse ?>
<?cs if:subcount(class.attrs) ?>
<!-- =========== FIELD SUMMARY =========== -->
<table id="lattrs" class="jd-sumtable"><tr><th colspan="12">XML Attributes</th></tr>
<?cs call:write_attr_summary(class.attrs) ?>
<?cs /if ?>

<?cs # if there are inherited attrs, write the table ?>
<?cs if:inhattrs ?>
<table id="inhattrs" class="jd-sumtable"><tr><th>
  <a href="#" class="toggle-all" onclick="return toggleAllInherited(this, null)">[Expand]</a>
  <div style="clear:left;">Inherited XML Attributes</div></th></tr>
<?cs each:cl=class.inherited ?>
<?cs if:subcount(cl.attrs) ?>
<tr><td colspan="12">
<?cs call:expando_trigger("inherited-attrs-"+cl.qualified, "closed") ?>From <?cs var:cl.kind ?>
<a href="<?cs var:toroot ?><?cs var:cl.link ?>"><?cs var:cl.qualified ?></a>
<div id="inherited-attrs-<?cs var:cl.qualified ?>">
  <div id="inherited-attrs-<?cs var:cl.qualified ?>-list"
        class="jd-inheritedlinks">
  </div>
  <div id="inherited-attrs-<?cs var:cl.qualified ?>-summary" style="display: none;">
    <table class="jd-sumtable-expando">
    <?cs call:write_attr_summary(cl.attrs) ?></table>
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
<table id="enumconstants" class="jd-sumtable"><tr><th colspan="12">Enum Values</th></tr>
<?cs set:count = #1 ?>
    <?cs each:field=class.enumConstants ?>
    <tr <?cs if:count % #2 ?>class="alt-color"<?cs /if ?> >
        <td class="jd-descrcol"><?cs call:type_link(field.type) ?>&nbsp;</td>
        <td class="jd-linkcol"><a href="<?cs var:toroot ?><?cs var:field.href ?>"><?cs var:field.name ?></a>&nbsp;</td>
        <td class="jd-descrcol" width="100%"><?cs call:short_descr(field) ?>&nbsp;</td>
    </tr>
    <?cs set:count = count + #1 ?>
    <?cs /each ?>
<?cs /if ?>

<?cs if:subcount(class.constants) ?>
<?cs # this next line must be exactly like this to be parsed by eclipse ?>
<!-- =========== FIELD SUMMARY =========== -->
<table id="constants" class="jd-sumtable"><tr><th colspan="12">Constants</th></tr>
<?cs call:write_constant_summary(class.constants) ?>
</table>
<?cs /if ?>

<?cs # if there are inherited constants, write the table ?>
<?cs if:inhconstants ?>
<table id="inhconstants" class="jd-sumtable"><tr><th>
  <a href="#" class="toggle-all" onclick="return toggleAllInherited(this, null)">[Expand]</a>
  <div style="clear:left;">Inherited Constants</div></th></tr>
<?cs each:cl=class.inherited ?>
<?cs if:subcount(cl.constants) ?>
<tr><td colspan="12">
<?cs call:expando_trigger("inherited-constants-"+cl.qualified, "closed") ?>From <?cs var:cl.kind ?>
<a href="<?cs var:toroot ?><?cs var:cl.link ?>"><?cs var:cl.qualified ?></a>
<div id="inherited-constants-<?cs var:cl.qualified ?>">
  <div id="inherited-constants-<?cs var:cl.qualified ?>-list"
        class="jd-inheritedlinks">
  </div>
  <div id="inherited-constants-<?cs var:cl.qualified ?>-summary" style="display: none;">
    <table class="jd-sumtable-expando">
    <?cs call:write_constant_summary(cl.constants) ?></table>
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
<table id="lfields" class="jd-sumtable"><tr><th colspan="12">Fields</th></tr>
<?cs call:write_field_summary(class.fields) ?>
</table>
<?cs /if ?>

<?cs # if there are inherited fields, write the table ?>
<?cs if:inhfields ?>
<table id="inhfields" class="jd-sumtable"><tr><th>
  <a href="#" class="toggle-all" onclick="return toggleAllInherited(this, null)">[Expand]</a>
  <div style="clear:left;">Inherited Fields</div></th></tr>
<?cs each:cl=class.inherited ?>
<?cs if:subcount(cl.fields) ?>
<tr><td colspan="12">
<?cs call:expando_trigger("inherited-fields-"+cl.qualified, "closed") ?>From <?cs var:cl.kind ?>
<a href="<?cs var:toroot ?><?cs var:cl.link ?>"><?cs var:cl.qualified ?></a>
<div id="inherited-fields-<?cs var:cl.qualified ?>">
  <div id="inherited-fields-<?cs var:cl.qualified ?>-list"
        class="jd-inheritedlinks">
  </div>
  <div id="inherited-fields-<?cs var:cl.qualified ?>-summary" style="display: none;">
    <table class="jd-sumtable-expando">
    <?cs call:write_field_summary(cl.fields) ?></table>
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
<table id="pubctors" class="jd-sumtable"><tr><th colspan="12">Public Constructors</th></tr>
<?cs call:write_method_summary(class.ctors.public) ?>
</table>
<?cs /if ?>

<?cs if:subcount(class.ctors.protected) ?>
<?cs # this next line must be exactly like this to be parsed by eclipse ?>
<!-- ======== CONSTRUCTOR SUMMARY ======== -->
<table id="proctors" class="jd-sumtable"><tr><th colspan="12">Protected Constructors</th></tr>
<?cs call:write_method_summary(class.ctors.protected) ?>
</table>
<?cs /if ?>

<?cs if:subcount(class.methods.public) ?>
<?cs # this next line must be exactly like this to be parsed by eclipse ?>
<!-- ========== METHOD SUMMARY =========== -->
<table id="pubmethods" class="jd-sumtable"><tr><th colspan="12">Public Methods</th></tr>
<?cs call:write_method_summary(class.methods.public) ?>
</table>
<?cs /if ?>

<?cs if:subcount(class.methods.protected) ?>
<?cs # this next line must be exactly like this to be parsed by eclipse ?>
<!-- ========== METHOD SUMMARY =========== -->
<table id="promethods" class="jd-sumtable"><tr><th colspan="12">Protected Methods</th></tr>
<?cs call:write_method_summary(class.methods.protected) ?>
</table>
<?cs /if ?>

<?cs # if there are inherited methods, write the table ?>
<?cs if:inhmethods ?>
<table id="inhmethods" class="jd-sumtable"><tr><th>
  <a href="#" class="toggle-all" onclick="return toggleAllInherited(this, null)">[Expand]</a>
  <div style="clear:left;">Inherited Methods</div></th></tr>
<?cs each:cl=class.inherited ?>
<?cs if:subcount(cl.methods) ?>
<tr><td colspan="12"><?cs call:expando_trigger("inherited-methods-"+cl.qualified, "closed") ?>
From <?cs var:cl.kind ?> <a href="<?cs var:toroot ?><?cs var:cl.link ?>"><?cs var:cl.qualified ?></a>
<div id="inherited-methods-<?cs var:cl.qualified ?>">
  <div id="inherited-methods-<?cs var:cl.qualified ?>-list"
        class="jd-inheritedlinks">
  </div>
  <div id="inherited-methods-<?cs var:cl.qualified ?>-summary" style="display: none;">
    <table class="jd-sumtable-expando">
    <?cs call:write_method_summary(cl.methods) ?></table>
  </div>
</div>
</td></tr>
<?cs /if ?>
<?cs /each ?>
</table>
<?cs /if ?>

</div><!-- jd-descr (summary) -->

<!-- Details -->

<?cs def:write_field_details(fields) ?>
<?cs each:field=fields ?>
<?cs # this next line must be exactly like this to be parsed by eclipse ?>
<div class="jd-details" id="<?cs var:field.anchor ?>"> 
    <h4 class="jd-details-title">
      <span class="normal">
        <?cs var:field.scope ?> 
        <?cs var:field.static ?> 
        <?cs var:field.final ?> 
        <?cs call:type_link(field.type) ?>
      </span>
        <?cs var:field.name ?>
    </h4>
    <div class="jd-details-descr"><?cs call:description(field) ?>
    <?cs if:subcount(field.constantValue) ?>
        <div class="jd-tagdata">
        <span class="jd-tagtitle">Constant Value: </span>
        <span>
            <?cs if:field.constantValue.isString ?>
                <?cs var:field.constantValue.str ?>
            <?cs else ?>
                <?cs var:field.constantValue.dec ?>
                (<?cs var:field.constantValue.hex ?>)
            <?cs /if ?>
        </span>
        </div>
    <?cs /if ?>
    </div>
</div>
<?cs /each ?>
<?cs /def ?>

<?cs def:write_method_details(methods) ?>
<?cs each:method=methods ?>
<?cs # this next line must be exactly like this to be parsed by eclipse ?>
<div class="jd-details" id="<?cs var:method.anchor ?>"> 
    <h4 class="jd-details-title">
      <span class="normal">
        <?cs var:method.scope ?> 
        <?cs var:method.static ?> 
        <?cs var:method.final ?> 
        <?cs var:method.abstract ?> 
        <?cs var:method.synchronized ?> 
        <?cs call:type_link(method.returnType) ?>
      </span>
      <span class="sympad"><?cs var:method.name ?></span>
      <span class="normal">(<?cs call:parameter_list(method.params) ?>)</span>
    </h4>
    <div class="jd-details-descr"><?cs call:description(method) ?></div>
</div>
<?cs /each ?>
<?cs /def ?>

<?cs def:write_attr_details(attrs) ?>
<?cs each:attr=attrs ?>
<?cs # this next line must be exactly like this to be parsed by eclipse ?>
<div class="jd-details" id="<?cs var:attr.anchor ?>"> 
    <h4 class="jd-details-title"><?cs var:attr.name ?></h4>
    <div class="jd-details-descr">
        <?cs call:description(attr) ?>

        <div class="jd-tagdata">
            <h5 class="jd-tagtitle">Related Methods</h5>
            <ul class="nolist">
            <?cs each:m=attr.methods ?>
                <li><a href="<?cs var:toroot ?><?cs var:m.href ?>"><?cs var:m.name ?></a></li>
            <?cs /each ?>
            </ul>
        </div>
    </div>
</div>
<?cs /each ?>
<?cs /def ?>


<!-- XML Attributes -->
<?cs if:subcount(class.attrs) ?>
<h2>XML Attributes</h2>
<?cs call:write_attr_details(class.attrs) ?>
<?cs /if ?>

<!-- Enum Values -->
<?cs if:subcount(class.enumConstants) ?>
<h2>Enum Values</h2>
<?cs call:write_field_details(class.enumConstants) ?>
<?cs /if ?>

<!-- Constants -->
<?cs if:subcount(class.constants) ?>
<h2>Constants</h2>
<?cs call:write_field_details(class.constants) ?>
<?cs /if ?>

<!-- Fields -->
<?cs if:subcount(class.fields) ?>
<h2>Fields</h2>
<?cs call:write_field_details(class.fields) ?>
<?cs /if ?>

<!-- Public ctors -->
<?cs if:subcount(class.ctors.public) ?>
<h2>Public Constructors</h2>
<?cs call:write_method_details(class.ctors.public) ?>
<?cs /if ?>

<?cs # this next line must be exactly like this to be parsed by eclipse ?>
<!-- ========= CONSTRUCTOR DETAIL ======== -->
<!-- Protected ctors -->
<?cs if:subcount(class.ctors.protected) ?>
<h2>Protected Constructors</h2>
<?cs call:write_method_details(class.ctors.protected) ?>
<?cs /if ?>

<?cs # this next line must be exactly like this to be parsed by eclipse ?>
<!-- ========= CONSTRUCTOR DETAIL ======== -->
<!-- Public methdos -->
<?cs if:subcount(class.methods.public) ?>
<h2>Public Methods</h2>
<?cs call:write_method_details(class.methods.public) ?>
<?cs /if ?>

<?cs # this next line must be exactly like this to be parsed by eclipse ?>
<!-- ========= METHOD DETAIL ======== -->
<?cs if:subcount(class.methods.protected) ?>
<h2>Protected Methods</h2>
<?cs call:write_method_details(class.methods.protected) ?>
<?cs /if ?>

<?cs # this next line must be exactly like this to be parsed by eclipse ?>
<!-- ========= END OF CLASS DATA ========= -->

<?cs include:"footer.cs" ?>
</div> <!-- jd-content -->

</div><!-- end doc-content -->

<?cs include:"trailer.cs" ?>

</body>
</html>
