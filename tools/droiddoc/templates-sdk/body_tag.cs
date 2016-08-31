<body class="gc-documentation <?cs
  if:(reference.gms || reference.gcm)
    ?>google<?cs
  /if ?><?cs
  if:(guide||develop||training||reference||tools||sdk)
    ?>develop<?cs
    if:reference
      ?> reference api apilevel-<?cs var:class.since ?><?cs var:package.since ?><?cs
    /if ?><?cs
  elif:design
    ?>design<?cs
  elif:distribute
    ?>distribute<?cs
  /if ?>">
<div id="doc-api-level" class="<?cs var:class.since ?><?cs var:package.since ?>" style="display:none"></div>
