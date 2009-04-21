<?cs include:"doctype.cs" ?>
<?cs include:"macros.cs" ?>
<html>
<?cs if:sdk.redirect ?>
  <head>
    <title>Redirecting...</title>
    <meta http-equiv="refresh" content="0;url=<?cs var:toroot ?>sdk/<?cs var:sdk.current ?>/index.html">
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

<?cs if:sdk.redirect ?>
  Redirecting to 
  <a href="<?cs var:toroot ?>sdk/<?cs var:sdk.current ?>/index.html">
  <?cs var:toroot ?>sdk/<?cs var:sdk.redirect ?>/index.html
  </a>...
<?cs else ?>
  
  <div id="jd-header" class="guide-header" >
    <span class="crumb">&nbsp;</span>
    <h1><?cs if:android.whichdoc == "online" ?>Download <?cs /if ?><?cs var:sdk.self ?></h1>
  </div>


<div id="jd-content">

    <p><em>
    <?cs var:sdk.date ?>
    </em></p>

<?cs if:sdk.not_latest_version ?>
  <div class="special">
    <p><strong>This is NOT the current Android SDK release.</strong></p>
    <p>Use the links under <strong>Current SDK Release</strong>, on the left, to be directed to the current SDK.</p>
  </div>
<?cs /if ?>
  
  
<?cs if:android.whichdoc != "online" ?>

<p>The sections below provide an overview of the SDK package. </p>

<?cs else ?>

<p>Before downloading, please read the <a href="requirements.html">
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

<?cs /if ?>

      <?cs call:tag_list(root.descr) ?>

<?cs /if ?>
</div><!-- end jd-content -->

<?cs include:"footer.cs" ?>
</div><!-- end doc-content -->

<?cs include:"trailer.cs" ?>

</body>
</html>



