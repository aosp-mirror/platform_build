<?cs include:"macros.cs" ?>
<html>
<?cs include:"head_tag.cs" ?>
<body>
<script type="text/javascript">
function toggle_inherited(base) {
    var list = document.getElementById(base + "-list");
    var summary = document.getElementById(base + "-summary");
    var trigger = document.getElementById(base + "-trigger");
    if (list.style.display == "none") {
        list.style.display = "block";
        summary.style.display = "none";
        trigger.src = "<?cs var:toroot ?>assets/triangle-open.png";
    } else {
        list.style.display = "none";
        summary.style.display = "block";
        trigger.src = "<?cs var:toroot ?>assets/triangle-close.png";
    }
}
</script>
<?cs include:"header.cs" ?>

<div class="g-unit" id="doc-content">

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


<div class="jd-descr">
<?cs call:deprecated_warning(class) ?>
<?cs if:subcount(class.descr) ?>
<h2>Class Overview</h2>
<p><?cs call:tag_list(class.descr) ?></p>
<?cs /if ?>

<?cs # this next line must be exactly like this to be parsed by eclipse ?>
<!-- ======== NESTED CLASS SUMMARY ======== -->
<?cs if:subcount(class.inners) ?>
<h4><?cs call:expando_trigger("nested-classes", "close") ?>Nested Classes</h4>
<?cs call:expandable_class_list("nested-classes", class.inners, "summary") ?>
<?cs /if ?>

<?cs if:subcount(class.subclasses.direct) ?>
<h4><?cs call:expando_trigger("subclasses-direct", "open") ?>Known Direct Subclasses</h4>
<?cs call:expandable_class_list("subclasses-direct", class.subclasses.direct, "list") ?>
<?cs /if ?>

<?cs if:subcount(class.subclasses.indirect) ?>
<h4><?cs call:expando_trigger("subclasses-indirect", "open") ?>Known Indirect Subclasses</h4>
<?cs call:expandable_class_list("subclasses-indirect", class.subclasses.indirect, "list") ?>
<?cs /if ?>

<?cs call:see_also_tags(class.seeAlso) ?>

</div><!-- jd-descr -->


<?cs # summar macros ?>

<?cs def:write_method_summary(methods) ?>
<?cs set:count = #1 ?>
<table class="jd-linktable">
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
        <td class="jd-linkcol" width="100%"><a href="<?cs var:toroot ?><?cs var:method.href ?>"><strong><?cs var:method.name ?></strong></a>(<?cs call:parameter_list(method.params) ?>)</td>
    </tr>
  <?cs if:subcount(method.shortDescr) || subcount(method.deprecated) ?>
    <tr <?cs if:count % #2 ?>class="alt-color"<?cs /if ?> >
          <td class="jd-commentrow"></td>
          <td class="jd-commentrow"><?cs call:short_descr(method) ?></td>
    </tr>
  <?cs /if ?>
<?cs set:count = count + #1 ?>
<?cs /each ?>
</table>
<?cs /def ?>

<?cs def:write_field_summary(fields) ?>
<?cs set:count = #1 ?>
<table class="jd-linktable">
    <?cs each:field=fields ?>
      <tr <?cs if:count % #2 ?>class="alt-color"<?cs /if ?> >
          <td class="jd-descrcol"><?cs var:field.scope ?>&nbsp;</td>
          <td class="jd-descrcol"><?cs var:field.static ?>&nbsp;</td>
          <td class="jd-descrcol"><?cs var:field.final ?>&nbsp;</td>
          <td class="jd-descrcol"><?cs call:type_link(field.type) ?>&nbsp;</td>
          <td class="jd-linkcol"><a href="<?cs var:toroot ?><?cs var:field.href ?>"><?cs var:field.name ?></a>&nbsp;</td>
          <td class="jd-descrcol" width="100%"><?cs call:short_descr(field) ?>&nbsp;</td>
      </tr>
      <?cs set:count = count + #1 ?>
    <?cs /each ?>
</table>
<?cs /def ?>

<?cs def:write_constant_summary(fields) ?>
<?cs set:count = #1 ?>
<table class="jd-linktable">

    <?cs each:field=fields ?>
    <tr <?cs if:count % #2 ?>class="alt-color"<?cs /if ?> >
        <td class="jd-descrcol"><?cs call:type_link(field.type) ?>&nbsp;</td>
        <td class="jd-linkcol"><a href="<?cs var:toroot ?><?cs var:field.href ?>"><?cs var:field.name ?></a>&nbsp;</td>
        <td class="jd-descrcol"><?cs call:short_descr(field) ?>&nbsp;</td>
    </tr>
    <?cs set:count = count + #1 ?>
    <?cs /each ?>
</table>
<?cs /def ?>

<?cs def:write_attr_summary(attrs) ?>
<?cs set:count = #1 ?>
<table class="jd-linktable">
    <tr>
        <th>Attribute name</th>
        <th>Related methods</th>
        <th>&nbsp;</th>
    </tr>
    <?cs each:attr=attrs ?>
    <tr <?cs if:count % #2 ?>class="alt-color"<?cs /if ?> >
        <td class="jd-linkcol"><a href="<?cs var:toroot ?><?cs var:attr.href ?>"><?cs var:attr.name ?></a></td>
        <td class="jd-linkcol"><?cs each:m=attr.methods 
            ?><a href="<?cs var:toroot ?><?cs var:m.href ?>"><?cs var:m.name ?></a><br/>
            <?cs /each ?>&nbsp;
        </td>
        <td class="jd-descrcol" width="100%"><?cs call:short_descr(attr) ?>&nbsp;</td>
    </tr>
    <?cs set:count = count + #1 ?>
    <?cs /each ?>
</table>
<?cs /def ?>

<?cs # end macros ?>

<div class="jd-descr">
<h2>Summary</h2>

<?cs # this next line must be exactly like this to be parsed by eclipse ?>
<!-- =========== FIELD SUMMARY =========== -->
<?cs if:subcount(class.attrs) ?>
<h3>XML Attributes</h3>
<?cs call:write_attr_summary(class.attrs) ?>
<?cs /if ?>

<?cs each:cl=class.inherited ?>
<?cs if:subcount(cl.attrs) ?>
<h4><?cs call:expando_trigger("inherited-attrs-"+cl.qualified, "open") ?>XML Attributes inherited
    from <?cs var:cl.kind ?>
    <a href="<?cs var:toroot ?><?cs var:cl.link ?>"><?cs var:cl.qualified ?></a>
</h4>
<div id="inherited-attrs-<?cs var:cl.qualified ?>">
  <div id="inherited-attrs-<?cs var:cl.qualified ?>-list"
          class="jd-inheritedlinks">
  </div>
  <div id="inherited-attrs-<?cs var:cl.qualified ?>-summary"
      style="display: none;">
  <?cs call:write_attr_summary(cl.attrs) ?>
  </div>
</div>
<?cs /if ?>
<?cs /each ?>



<?cs if:subcount(class.enumConstants) ?>
<?cs # this next line must be exactly like this to be parsed by eclipse ?>
<!-- =========== ENUM CONSTANT SUMMARY =========== -->
<h3>Enum Values</h3>
<?cs set:count = #1 ?>
<table class="jd-linktable">
    <?cs each:field=class.enumConstants ?>
    <tr <?cs if:count % #2 ?>class="alt-color"<?cs /if ?> >
        <td class="jd-descrcol"><?cs call:type_link(field.type) ?>&nbsp;</td>
        <td class="jd-linkcol"><a href="<?cs var:toroot ?><?cs var:field.href ?>"><?cs var:field.name ?></a>&nbsp;</td>
        <td class="jd-descrcol" width="100%"><?cs call:short_descr(field) ?>&nbsp;</td>
    </tr>
    <?cs set:count = count + #1 ?>
    <?cs /each ?>
</table>
<?cs /if ?>

<?cs if:subcount(class.constants) ?>
<?cs # this next line must be exactly like this to be parsed by eclipse ?>
<!-- =========== FIELD SUMMARY =========== -->
<h3>Constants</h3>
<?cs call:write_constant_summary(class.constants) ?>
<?cs /if ?>

<?cs each:cl=class.inherited ?>
<?cs if:subcount(cl.constants) ?>
<h4><?cs call:expando_trigger("inherited-constants-"+cl.qualified, "open") ?>Constants inherited
    from <?cs var:cl.kind ?>
    <a href="<?cs var:toroot ?><?cs var:cl.link ?>"><?cs var:cl.qualified ?></a>
</h4>
<div id="inherited-constants-<?cs var:cl.qualified ?>">
<div id="inherited-constants-<?cs var:cl.qualified ?>-list"
        class="jd-inheritedlinks">

</div>
<div id="inherited-constants-<?cs var:cl.qualified ?>-summary"
    style="display: none;">
<?cs call:write_constant_summary(cl.constants) ?>
</div>
</div>
<?cs /if ?>
<?cs /each ?>


<?cs if:subcount(class.fields) ?>
<?cs # this next line must be exactly like this to be parsed by eclipse ?>
<!-- =========== FIELD SUMMARY =========== -->
<h3>Fields</h3>
<?cs call:write_field_summary(class.fields) ?>
<?cs /if ?>

<?cs each:cl=class.inherited ?>
<?cs if:subcount(cl.fields) ?>
<h4><?cs call:expando_trigger("inherited-fields-"+cl.qualified, "open") ?>Fields inherited
    from <?cs var:cl.kind ?>
    <a href="<?cs var:toroot ?><?cs var:cl.link ?>"><?cs var:cl.qualified ?></a>
</h4>
<div id="inherited-fields-<?cs var:cl.qualified ?>">
<div id="inherited-fields-<?cs var:cl.qualified ?>-list"
        class="jd-inheritedlinks">

</div>
<div id="inherited-fields-<?cs var:cl.qualified ?>-summary"
    style="display: none;">
<?cs call:write_field_summary(cl.fields) ?>
</div>
</div>
<?cs /if ?>
<?cs /each ?>


<?cs if:subcount(class.ctors.public) ?>
<?cs # this next line must be exactly like this to be parsed by eclipse ?>
<!-- ======== CONSTRUCTOR SUMMARY ======== -->
<h3>Public Constructors</h3>
<?cs call:write_method_summary(class.ctors.public) ?>
<?cs /if ?>

<?cs if:subcount(class.ctors.protected) ?>
<?cs # this next line must be exactly like this to be parsed by eclipse ?>
<!-- ======== CONSTRUCTOR SUMMARY ======== -->
<h3>Protected Constructors</h3>
<?cs call:write_method_summary(class.ctors.protected) ?>
<?cs /if ?>

<?cs if:subcount(class.methods.public) ?>
<?cs # this next line must be exactly like this to be parsed by eclipse ?>
<!-- ========== METHOD SUMMARY =========== -->
<h3>Public Methods</h3>
<?cs call:write_method_summary(class.methods.public) ?>
<?cs /if ?>

<?cs if:subcount(class.methods.protected) ?>
<?cs # this next line must be exactly like this to be parsed by eclipse ?>
<!-- ========== METHOD SUMMARY =========== -->
<h3>Protected Methods</h3>
<?cs call:write_method_summary(class.methods.protected) ?>
<?cs /if ?>

<?cs each:cl=class.inherited ?>
<?cs if:subcount(cl.methods) ?>
<h4><?cs call:expando_trigger("inherited-methods-"+cl.qualified, "open") ?>Methods inherited
    from <?cs var:cl.kind ?>
    <a href="<?cs var:toroot ?><?cs var:cl.link ?>"><?cs var:cl.qualified ?></a>
</h4>
<div id="inherited-methods-<?cs var:cl.qualified ?>">
<div id="inherited-methods-<?cs var:cl.qualified ?>-list"
        class="jd-inheritedlinks">

</div>
<div id="inherited-methods-<?cs var:cl.qualified ?>-summary"
    style="display: none;">
<?cs call:write_method_summary(cl.methods) ?>
</div>
</div>
<?cs /if ?>
<?cs /each ?>

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
        <?cs var:method.name ?>(<?cs call:parameter_list(method.params) ?>)
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
<?cs include:"analytics.cs" ?>
</body>
</html>
