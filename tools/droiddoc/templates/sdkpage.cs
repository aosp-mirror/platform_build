<?cs include:"macros.cs" ?>
<html>
<?cs include:"head_tag.cs" ?>
<body class="gc-documentation">
<a name="top"></a>
<?cs call:custom_masthead() ?>

<?cs call:sdk_nav() ?>


<div class="g-unit" id="doc-content" >

<div id="jd-content" style="min-width:820px">

<h1><?cs var:sdk.version ?></h1>
<p><em>
<?cs var:sdk.date ?> - 
<a href="RELEASENOTES.html">Release Notes</a>
</em></p>

<div class="sidebox-wrapper" style="width:250px">
<div class="sidebox-inner">
<h2>Get Started</h2>
<p><a href="requirements.html">System and Sofware Requirements &rarr;</a></p>
<p><a href="installing.html">Guide to Installing the SDK &rarr;</a></p>

<h2>Upgrade</h2>
<p><a href="upgrading.html">Upgrading the SDK &rarr;</a></p>
<p><a href="">API changes overview &rarr;</a></p>
<p><a href="">API differences report &rarr;</a></p>

<h2>Using Eclipse?</h2>
<p>Android provides an Eclipse plugin to help make programming and debugging easier.</p>
<p><a href="">Install Eclipse plugin &rarr;</a></p>
</div>
</div>


<p>Before downloading, please read the <a href="terms.html">Terms</a> 
    that govorn the use of the Android SDK.</p>

<p class="special-note"><strong>Please note:</strong> The Android SDK is under active development.
  Please keep this in mind as you explore its capabilities. If you discover any issues, we 
  welcome you to notify us of them via our Issue Tracker.</p>

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
<a href="http://dl.google.com/android/<?cs var:sdk.win_download ?>"><?cs var:sdk.win_download ?></a>
  </td>
  <td><?cs var:sdk.win_bytes ?></td>
  <td><?cs var:sdk.win_checksum ?></td>
</tr>
<tr class="alt-color">
  <td>Mac OS X (intel)</td>
  <td>
<a href="http://dl.google.com/android/<?cs var:sdk.mac_download ?>"><?cs var:sdk.mac_download ?></a>
  </td>
  <td><?cs var:sdk.mac_bytes ?></td>
  <td><?cs var:sdk.mac_checksum ?></td>
</tr>
<tr>
  <td>Linux (i386)</td>
  <td>
<a href="http://dl.google.com/android/<?cs var:sdk.linux_download ?>"><?cs var:sdk.linux_download ?></a>
  </td>
  <td><?cs var:sdk.linux_bytes ?></td>
  <td><?cs var:sdk.linux_checksum ?></td>
</tr>
</table>


</div><!-- end jd-content -->

<?cs include:"footer.cs" ?>
</div><!-- end doc-content -->
</div><!-- end body-content -->
<?cs include:"analytics.cs" ?>
</body>
</html>



