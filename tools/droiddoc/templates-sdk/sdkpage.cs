<?cs include:"doctype.cs" ?>
<?cs include:"macros.cs" ?>
<html>
<?cs if:sdk.redirect ?>
  <head>
    <title>Redirecting...</title>
    <meta http-equiv="refresh" content="0;url=<?cs var:toroot ?>sdk/<?cs var:sdk.redirect ?>/index.html">
    <link href="<?cs var:toroot ?>assets/android-developer-docs.css" rel="stylesheet" type="text/css" />
  </head>
<?cs else ?>
  <?cs include:"head_tag.cs" ?>
<?cs /if ?>
<body class="gc-documentation">
<a name="top"></a>
<?cs call:custom_masthead() ?>

<?cs call:sdk_nav() ?>

  
<div class="g-unit" id="doc-content" >

<div id="jd-content">

<?cs if:sdk.redirect ?>
  Redirecting to 
  <a href="<?cs var:toroot ?>sdk/<?cs var:sdk.redirect ?>/index.html">
  <?cs var:toroot ?>sdk/<?cs var:sdk.redirect ?>/index.html
  </a>...
<?cs else ?>
  
    <h1><?cs var:page.title ?></h1>
    <p><em>
    <?cs var:sdk.date ?>
    </em></p>

<?cs if:sdk.not_latest_version ?>
  <div class="special">
    <p><strong>This is NOT the latest version of the Android SDK</strong>.</p>
    <p>Go to the <a href="<?cs var:toroot ?>sdk/index.html">SDK home page</a> to be directed to the latest version.</p>
  </div>
<?cs /if ?>
  
  
<p>Before downloading, please read the <a href="<?cs var:toroot ?>sdk/<?cs var:sdk.version ?>/requirements.html">
System Requirements</a> document. As you start the download, you will also need to review and agree to 
the Terms and Conditions that govern the use of the Android SDK. </p>
  
  <table class="download">
    <tr>
      <th>Platform</th>
      <th>Package</th>
      <th>Size</th>
      <th>MD5 Checksum</th>
  </tr>
  <tr>
    <td>Windows</td>
    <td>
  <a href="<?cs var:toroot ?>sdk/download.html?v=<?cs var:sdk.win_download ?>"><?cs var:sdk.win_download ?></a>
    </td>
    <td><?cs var:sdk.win_bytes ?> bytes</td>
    <td><?cs var:sdk.win_checksum ?></td>
  </tr>
  <tr class="alt-color">
    <td>Mac OS X (intel)</td>
    <td>
  <a href="<?cs var:toroot ?>sdk/download.html?v=<?cs var:sdk.mac_download ?>"><?cs var:sdk.mac_download ?></a>
    </td>
    <td><?cs var:sdk.mac_bytes ?> bytes</td>
    <td><?cs var:sdk.mac_checksum ?></td>
  </tr>
  <tr>
    <td>Linux (i386)</td>
    <td>
  <a href="<?cs var:toroot ?>sdk/download.html?v=<?cs var:sdk.linux_download ?>"><?cs var:sdk.linux_download ?></a>
    </td>
    <td><?cs var:sdk.linux_bytes ?> bytes</td>
    <td><?cs var:sdk.linux_checksum ?></td>
  </tr>
  </table>
  
      <?cs call:tag_list(root.descr) ?>

<?cs /if ?>

</div><!-- end jd-content -->

<?cs include:"footer.cs" ?>
</div><!-- end doc-content -->

<?cs include:"trailer.cs" ?>

</body>
</html>



