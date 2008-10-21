<?cs # A link to a package ?>
<?cs def:package_link(pkg)) ?>
<a href="<?cs var:toroot ?><?cs var:pkg.link ?>"><?cs var:pkg.name ?></a>
<?cs /def ?>


<?cs # A link to a type, or not if it's a primitive type
        link: whether to create a link at the top level, always creates links in
              recursive invocations.
        Expects the following fields:
            .name
            .link
            .isPrimitive
            .superBounds.N.(more links)   (... super ... & ...)
            .extendsBounds.N.(more links) (... extends ... & ...)
            .typeArguments.N.(more links) (< ... >)
?>
<?cs def:type_link_impl(type, link) ?><?cs
    if:type.link && link=="true" ?><a href="<?cs var:toroot ?><?cs var:type.link ?>"><?cs /if
        ?><?cs var:type.label ?><?cs if:type.link && link=="true" ?></a><?cs /if ?><?cs
    if:subcount(type.extendsBounds) ?><?cs
        each:t=type.extendsBounds ?><?cs
            if:first(t) ?>&nbsp;extends&nbsp;<?cs else ?>&nbsp;&amp;&nbsp;<?cs /if ?><?cs
            call:type_link_impl(t, "true") ?><?cs
        /each ?><?cs
    /if ?><?cs
    if:subcount(type.superBounds) ?><?cs
        each:t=type.superBounds ?><?cs
            if:first(t) ?>&nbsp;super&nbsp;<?cs else ?>&nbsp;&amp;&nbsp;<?cs /if ?><?cs
            call:type_link_impl(t, "true") ?><?cs
        /each ?><?cs
    /if ?><?cs

    if:subcount(type.typeArguments)
        ?>&lt;<?cs each:t=type.typeArguments ?><?cs call:type_link_impl(t, "true") ?><?cs
            if:!last(t) ?>,&nbsp;<?cs /if ?><?cs
        /each ?>&gt;<?cs
    /if ?><?cs
/def ?>


<?cs def:class_name(type) ?><?cs call:type_link_impl(type, "false") ?><?cs /def ?>
<?cs def:type_link(type) ?><?cs call:type_link_impl(type, "true") ?><?cs /def ?>

<?cs # A comma separated parameter list ?>
<?cs def:parameter_list(params) ?><?cs
    each:param = params ?><?cs
        call:type_link(param.type)?> <?cs
        var:param.name ?><?cs
        if: name(param)!=subcount(params)-1?>, <?cs /if ?><?cs
    /each ?><?cs
/def ?>


<?cs # Print a list of tags (e.g. description text ?>
<?cs def:tag_list(tags) ?><?cs
    each:tag = tags ?><?cs
        if:tag.name == "Text" ?><?cs var:tag.text?><?cs
        elif:tag.kind == "@more" ?><p><?cs
        elif:tag.kind == "@see" ?><a href="<?cs var:toroot ?><?cs var:tag.href ?>"><?cs var:tag.label ?></a><?cs
        elif:tag.kind == "@seeHref" ?><a href="<?cs var:tag.href ?>"><?cs var:tag.label ?></a><?cs
        elif:tag.kind == "@seeJustLabel" ?><?cs var:tag.label ?><?cs
        elif:tag.kind == "@code" ?><code class="Code prettyprint"><?cs var:tag.text ?></code><?cs
        elif:tag.kind == "@samplecode" ?><pre class="Code prettyprint"><?cs var:tag.text ?></pre><?cs
        elif:tag.name == "@sample" ?><pre class="Code prettyprint"><?cs var:tag.text ?></pre><?cs
        elif:tag.name == "@include" ?><?cs var:tag.text ?><?cs
        elif:tag.kind == "@docRoot" ?><?cs var:toroot ?><?cs
        elif:tag.kind == "@inheritDoc" ?><?cs # This is the case when @inheritDoc is in something
                                                that doesn't inherit from anything?><?cs
        elif:tag.kind == "@attr" ?><?cs
        else ?>{<?cs var:tag.name?> <?cs var:tag.text ?>}<?cs
        /if ?><?cs
    /each ?><?cs
/def ?>


<?cs # The message about This xxx is deprecated. ?>
<?cs def:deprecated_text(kind) ?>
This <?cs var:kind ?> is deprecated.
<?cs /def ?>


<?cs # Show the short-form description of something.  These come from shortDescr and deprecated ?>
<?cs def:short_descr(obj) ?><?cs
    if:subcount(obj.deprecated) ?>
        <em><?cs call:deprecated_text(obj.kind) ?>
        <?cs call:tag_list(obj.deprecated) ?></em><?cs
    else ?><?cs call:tag_list(obj.shortDescr) ?><?cs
    /if ?><?cs
/def ?>

<?cs # Show the red box with the deprecated warning ?>
<?cs def:deprecated_warning(obj) ?>
<?cs if:subcount(obj.deprecated) ?><p>
<p class="warning jd-deprecated-warning">
    <strong><?cs call:deprecated_text(obj.kind) ?></strong>
    <?cs call:tag_list(obj.deprecated) ?>
</p>
<?cs /if ?>
<?cs /def ?>

<?cs # print the See Also: section ?>
<?cs def:see_also_tags(also) ?>
<?cs if:subcount(also) ?>
<div class="jd-tagdata">
    <h4 class="jd-tagtitle">See Also</h4>
    <ul class="nolist">
    <?cs each:tag=also
    ?><li><?cs
        if:tag.kind == "@see" ?><a href="<?cs var:toroot ?><?cs var:tag.href ?>"><?cs
                var:tag.label ?></a><?cs
        elif:tag.kind == "@seeHref" ?><a href="<?cs var:tag.href ?>"><?cs var:tag.label ?></a><?cs
        elif:tag.kind == "@seeJustLabel" ?><?cs var:tag.label ?><?cs
        else ?>[ERROR: Unknown @see kind]<?cs
        /if ?></li>
    <?cs /each ?>
    </table>
    <ul>
</div>
<?cs /if ?>
<?cs /def ?>


<?cs # Print the long-form description for something.
        Uses the following fields: deprecated descr seeAlso
    ?>
<?cs def:description(obj) ?>

<?cs call:deprecated_warning(obj) ?>
<?cs call:tag_list(obj.descr) ?>

<?cs if:subcount(obj.attrRefs) ?>
<div class="jd-tagdata">
    <h4 class="jd-tagtitle">Related XML Attributes</h4>
    <ul class="nolist">
    <?cs each:attr=obj.attrRefs ?>
        <li><a href="<?cs var:toroot ?><?cs var:attr.href ?>"><?cs var:attr.name ?></a></li>
    <?cs /each ?>
    </ul>
</div>
<?cs /if ?>

<?cs if:subcount(obj.paramTags) ?>
<div class="jd-tagdata">
    <h4 class="jd-tagtitle">Parameters</h4>
    <table class="jd-tagtable">
    <?cs each:tag=obj.paramTags
    ?><tr>
        <th><?cs if:tag.isTypeParameter ?>&lt;<?cs /if ?><?cs var:tag.name
                ?><?cs if:tag.isTypeParameter ?>&gt;<?cs /if ?></td>
        <td><?cs call:tag_list(tag.comment) ?></td>
      </tr>
    <?cs /each ?>
    </table>
</div>
<?cs /if ?>


<?cs if:subcount(obj.returns) ?>
<div class="jd-tagdata">
    <h4 class="jd-tagtitle">Returns</h4>
    <ul class="nolist"><li><?cs call:tag_list(obj.returns) ?></li></ul>
</div>
<?cs /if ?>

<?cs if:subcount(obj.throws) ?>
<div class="jd-tagdata">
    <h4 class="jd-tagtitle">Throws</h4>
    <table class="jd-tagtable">
    <?cs each:tag=obj.throws
    ?>  <tr>
            <th><?cs call:type_link(tag.type) ?></td>
            <td><?cs call:tag_list(tag.comment) ?></td>
        </tr>
    <?cs /each ?>
    </table>
</div>
<?cs /if ?>

<?cs call:see_also_tags(obj.seeAlso) ?>

<?cs /def ?>


<?cs # A table of links to classes with descriptions, as in a package file or the nested classes ?>
<?cs def:class_link_table(classes) ?>
<?cs set:count = #1 ?>
<table class="jd-linktable"><?cs
    each:cl=classes ?>
      <tr <?cs if:count % #2 ?>class="alt-color"<?cs /if ?> >
            <td class="jd-linkcol"><?cs call:type_link(cl.type) ?></td>
            <td class="jd-descrcol" width="100%"><?cs call:short_descr(cl) ?>&nbsp;</td>
        </tr><?cs set:count = count + #1 ?><?cs
    /each ?>
</table>
<?cs /def ?>

<?cs # A list of links to classes, for use in the side navigation of packages ?>
<?cs def:class_link_list(label, classes) ?>
<?cs if:subcount(classes) ?>
  <li><h2><?cs var:label ?></h2>
    <ul>
    <?cs each:cl=classes ?>
      <li><?cs call:type_link(cl.type) ?></li>
    <?cs /each ?>
    </ul>
  </li>
<?cs /if ?>
<?cs /def ?>

<?cs # A list of links to classes, for use in the side navigation of classes ?>
<?cs def:list(label, classes) ?>
<?cs if:subcount(classes) ?>
  <li><h2><?cs var:label ?></h2>
    <ul>
    <?cs each:cl=classes ?>
        <li <?cs if:class.name == cl.label?>class="selected"<?cs /if ?>><?cs call:type_link(cl) ?></li>
    <?cs /each ?>
    </ul>
  </li>
<?cs /if ?>
<?cs /def ?>

<?cs # An expando trigger ?>
<?cs def:expando_trigger(id, default) ?>
<a href="javascript:toggle_inherited('<?cs var:id ?>')" class="jd-expando-trigger"
        ><img id="<?cs var:id ?>-trigger"
        src="<?cs var:toroot ?>assets/triangle-<?cs var:default ?>.png"
        class="jd-expando-trigger" /></a>
<?cs /def ?>

<?cs # An expandable list of classes ?>
<?cs def:expandable_class_list(id, classes, default) ?>
    <div id="<?cs var:id ?>">
        <div id="<?cs var:id ?>-list"
                class="jd-inheritedlinks"
                <?cs if:default != "list" ?>style="display: none;"<?cs /if ?>
                >
            <?cs each:cl=classes ?>
                <?cs call:type_link(cl.type) ?><?cs if:!last(cl) ?>,<?cs /if ?>
            <?cs /each ?>
        </div>
        <div id="<?cs var:id ?>-summary"
                <?cs if:default != "summary" ?>style="display: none;"<?cs /if ?>
                >

            <?cs call:class_link_table(classes) ?>
        </div>
    </div>
<?cs /def ?>


<?cs include:"customization.cs" ?>

