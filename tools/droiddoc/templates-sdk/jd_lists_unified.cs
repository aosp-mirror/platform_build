<?cs # generate metadata file for samples only ?><?cs
if:samples_only ?>METADATA['<?cs var:metadata.lang ?>'].develop = METADATA['<?cs var:metadata.lang ?>'].develop.concat([
<?cs var:reference_tree ?>
]);
<?cs # generate standard unified metadata file ?><?cs
else ?>window.METADATA = window.METADATA || {};
METADATA['<?cs var:metadata.lang ?>'] = {};

METADATA['<?cs var:metadata.lang ?>'].about = [];
METADATA['<?cs var:metadata.lang ?>'].design = [];
METADATA['<?cs var:metadata.lang ?>'].develop = [];
METADATA['<?cs var:metadata.lang ?>'].distribute = [];
METADATA['<?cs var:metadata.lang ?>'].extras = [];

<?cs var:reference_tree ?>
<?cs /if ?>