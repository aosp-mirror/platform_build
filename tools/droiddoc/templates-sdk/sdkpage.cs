<?cs include:"doctype.cs" ?>
<?cs include:"macros.cs" ?>
<html>
<?cs if:sdk.redirect ?>
  <head>
    <title>Redirecting...</title>
    <meta http-equiv="refresh" content="0;url=<?cs var:toroot ?>sdk/<?cs 
      if:sdk.redirect.path ?><?cs var:sdk.redirect.path ?><?cs 
      else ?>index.html<?cs /if ?>">
    <link href="<?cs var:toroot ?>assets/android-developer-docs.css" rel="stylesheet" type="text/css" />
  </head>
<?cs else ?>
  <?cs include:"head_tag.cs" ?>
<?cs /if ?>
<body class="gc-documentation">
<a name="top"></a>
<?cs call:custom_masthead() ?>

<?cs call:sdk_nav() ?>

<?cs if:sdk.redirect ?>

<div class="g-unit">
  <div id="jd-content">
    <p>Redirecting to 
    <a href="<?cs var:toroot ?>sdk/<?cs 
      if:sdk.redirect.path ?><?cs var:sdk.redirect.path ?><?cs
      else ?>index.html<?cs /if ?>"><?cs
      if:sdk.redirect.path ?><?cs var:sdk.redirect.path ?><?cs
      else ?>Download the SDK<?cs /if ?>
    </a> ...</p>
<?cs else ?>
<div class="g-unit" id="doc-content" >
  <div id="jd-header" class="guide-header" >
    <span class="crumb">&nbsp;</span>
    <h1><?cs if:android.whichdoc == "online" ?>Download the <?cs /if ?><?cs var:page.title ?></h1>
  </div>

  <div id="jd-content">
    <?cs 
    if:ndk ?><?cs 
    else ?><?cs 
      if:android.whichdoc == "online" ?><p><em><?cs 
      var:sdk.date ?></em></p><?cs 
      /if ?><?cs
    /if ?>

<?cs if:sdk.not_latest_version ?>
  <div class="special">
    <p><strong>This is NOT the current Android SDK release.</strong></p>
    <p><a href="/sdk/index.html">Download the current Android SDK</a></p>
  </div>
<?cs /if ?>

<?cs if:android.whichdoc != "online" && !android.preview ?>

<!-- <p>The sections below provide an overview of how to install the SDK package. </p> -->

<?cs else ?>
  <?cs if:ndk ?>

<p>The Android NDK is a companion tool to the Android SDK that lets Android
application developers build performance-critical portions of their apps in
native code. It is designed for use <em>only</em> in conjunction with the
Android SDK, so if you have not already installed the latest Android SDK, please
do so before downloading the NDK. Also, please read <a href="#overview">What is 
the Android NDK?</a> to get an understanding of what the NDK offers and whether
it will be useful to you.</p>

<p>Select the download package that is appropriate for your development
computer. </p>

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
  <a href="http://dl.google.com/android/ndk/<?cs var:ndk.win_download ?>"><?cs var:ndk.win_download ?></a>
    </td>
    <td><?cs var:ndk.win_bytes ?> bytes</td>
    <td><?cs var:ndk.win_checksum ?></td>
  </tr>
  <tr class="alt-color">
    <td>Mac OS X (intel)</td>
    <td>
  <a href="http://dl.google.com/android/ndk/<?cs var:ndk.mac_download ?>"><?cs var:ndk.mac_download ?></a>
    </td>
    <td><?cs var:ndk.mac_bytes ?> bytes</td>
    <td><?cs var:ndk.mac_checksum ?></td>
  </tr>
  <tr>
    <td>Linux 32/64-bit (x86)</td>
    <td>
  <a href="http://dl.google.com/android/ndk/<?cs var:ndk.linux_download ?>"><?cs var:ndk.linux_download ?></a>
    </td>
    <td><?cs var:ndk.linux_bytes ?> bytes</td>
    <td><?cs var:ndk.linux_checksum ?></td>
  </tr>
  </table>

  <?cs else ?><?cs if:android.whichdoc == "online" ?>

  <?cs if:sdk.preview ?>
  <p>Welcome developers! The next release of the Android platform will be
  Android 1.6 and we are pleased to announce the availability of an early look
  SDK to give you a head-start on developing applications for it. </p>

  <p>The Android <?cs var:sdk.preview.version ?> platform includes a variety of
  improvements and new features for users and developers. Additionally, the SDK
  itself introduces several new capabilities that enable you to develop
  applications more efficiently. See the <a href="features.html">Android <?cs
  var:sdk.preview.version ?> Platform Highlights</a> document for a list of 
  highlights.</p>
<?cs /if ?> 
<?cs # end if NDK ... the following is for the SDK ?>

<?cs #  
    <div class="toggle-content special">
    <p>The Android SDK has changed! If you've worked with the Android SDK before, 
    you will notice several important differences:</p>
    
    <div class="toggle-content-toggleme" style="display:none">
    <ul style="padding-bottom:.0;">
    <li style="margin-top:.5em">The SDK downloadable package includes <em>only</em>
    the latest version of the Android SDK Tools.</li>
    <li>Once you've installed the SDK, you now use the Android SDK and AVD Manager
    to download all of the SDK components that you need, such as Android platforms,
    SDK add-ons, tools, and documentation. </li>
    <li>The new approach is modular &mdash; you can install only the components you
    need and update any or all components without affecting other parts of your
    development environment.</li>
    <li>In short, once you've installed the new SDK, you will not need to download
    an SDK package again. Instead, you will use the Android SDK and AVD Manager to
    keep your development environment up-to-date. </li>
    </ul>
    <p style="margin-top:0">If you are currently using the Android 1.6 SDK, you
    do not need to install the new SDK, because your existing SDK already 
    includes the Android SDK and AVD Manager tool. To develop against Android 
    2.0.1, for example, you can just download the Android 2.0.1 platform (and 
    updated SDK Tools) into your existing SDK. Refer to <a 
    href="adding-components.html">Adding SDK Components</a>.</p>
    </div>
    
    <a href='#' class='toggle-content-button show' onclick="toggleContent(this,true);return false;">
      <span>show more</span><span style='display:none'>show less</span>
    </a>
  </div>
?>

  <p>Welcome Developers! If you are new to the Android SDK, please read the <a
href="#quickstart">Quick Start</a>, below, for an overview of how to install and
set up the SDK. </p>

  <p>If you are already using the Android SDK and would like to update to the
latest tools or platforms, please use the <em>Android SDK and AVD Manager</em>
to get the components, rather than downloading a new SDK package.</p>

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
  <a onclick="onDownload(this)" href="http://dl.google.com/android/<?cs var:sdk.win_download
?>"><?cs var:sdk.win_download ?></a>
    </td>
    <td><?cs var:sdk.win_bytes ?> bytes</td>
    <td><?cs var:sdk.win_checksum ?></td>
  </tr>
  <tr class="alt-color">
    <td>Mac OS X (intel)</td>
    <td>
  <a onclick="onDownload(this)" href="http://dl.google.com/android/<?cs var:sdk.mac_download
?>"><?cs var:sdk.mac_download ?></a>
    </td>
    <td><?cs var:sdk.mac_bytes ?> bytes</td>
    <td><?cs var:sdk.mac_checksum ?></td>
  </tr>
  <tr>
    <td>Linux (i386)</td>
    <td>
  <a onclick="onDownload(this)" href="http://dl.google.com/android/<?cs var:sdk.linux_download
?>"><?cs var:sdk.linux_download ?></a>
    </td>
    <td><?cs var:sdk.linux_bytes ?> bytes</td>
    <td><?cs var:sdk.linux_checksum ?></td>
  </tr>
  <?cs if:adt.zip_download ?>
  <tr class="alt-color">
    <td>ADT Plugin for Eclipse <?cs var:adt.zip_version ?></td>
    <td>
  <a href="http://dl.google.com/android/<?cs var:adt.zip_download ?>"><?cs var:adt.zip_download ?></a>
    </td>
    <td><?cs var:adt.zip_bytes ?> bytes</td>
    <td><?cs var:adt.zip_checksum ?></td>
  </tr>
  <?cs /if ?>
  </table>


<div id="next-steps" style="display:none">
  <p><b>Your download of <em><span id="filename"></span></em> has begun!</b></p>
</div>

<script type="text/javascript">
function onDownload(link) {
  $(link).parent().parent().children().css('background', '#fff');
  $("#filename").text($(link).html());
  $("#next-steps").show();
}
</script>

  <?cs /if ?>
 <?cs /if ?>
<?cs /if ?> 

<?cs if:android.whichdoc != "online" && sdk.preview ?>
  <p>Welcome developers! The next release of the Android platform will be
Android <?cs var:sdk.preview.version ?> and we are pleased to announce the
availability of an early look SDK to give you a head-start on developing
applications for it. </p>

  <p>The Android <?cs var:sdk.preview.version ?> platform includes a variety of
improvements and new features for users and developers. Additionally, the SDK
itself introduces several new capabilities that enable you to develop
applications more efficiently. See the <a
href="http://developer.android.com/sdk/preview/features.html">Android 
<?cs var:sdk.preview.version ?> Highlights</a> document for a list of
highlights.</p>
<?cs /if ?>

      <?cs call:tag_list(root.descr) ?>

<?cs /if ?>
</div><!-- end jd-content -->

<?cs if:!sdk.redirect ?>
     <?cs include:"footer.cs" ?>
<?cs /if ?>

</div><!-- end doc-content -->

<?cs include:"trailer.cs" ?>

</body>
</html>



