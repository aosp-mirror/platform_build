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
<body class="gc-documentation" itemscope itemtype="http://schema.org/CreativeWork">
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
<?cs # else, if NOT redirect ...
#
#
# The following is for SDK/NDK pages
#
#
?>

<div class="g-unit" id="doc-content" >
  <div id="jd-header" class="guide-header" >
    <span class="crumb">&nbsp;</span>
    <h1 itemprop="name"><?cs if:android.whichdoc == "online" ?>Download the <?cs /if ?><?cs
var:page.title ?></h1>
  </div>

  <div id="jd-content" itemprop="description">

<?cs if:sdk.not_latest_version ?>
  <div class="special">
    <p><strong>This is NOT the current Android SDK release.</strong></p>
    <p><a href="/sdk/index.html">Download the current Android SDK</a></p>
  </div>
<?cs /if ?>


<?cs if:ndk ?>
<?cs #
#
#
#
#
#
#
# the following is for the NDK
#
# (nested in if/else redirect)
#
#
#
#
?>

<p>The Android NDK is a companion tool to the Android SDK that lets you build
performance-critical portions of your apps in native code. It provides headers and
libraries that allow you to build activities, handle user input, use hardware sensors,
access application resources, and more, when programming in C or C++. If you write
native code, your applications are still packaged into an .apk file and they still run
inside of a virtual machine on the device. The fundamental Android application model
does not change.</p>

<p>Using native code does not result in an automatic performance increase, 
but always increases application complexity. If you have not run into any limitations
using the Android framework APIs, you probably do not need the NDK. Read <a 
href="<?cs var:toroot ?>sdk/ndk/overview.html">What is the NDK?</a> for more information about what
the NDK offers and whether it will be useful to you.
</p>
<p>
The NDK is designed for use <em>only</em> in conjunction with the
Android SDK. If you have not already installed and setup the <a
href="http://developer.android.com/sdk/index.html">Android SDK</a>, please
do so before downloading the NDK. 
</p>

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

  <?cs else ?>
<?cs # end if NDK ... 
#
#
#
#
#
#
# the following is for the SDK
#
# (nested in if/else redirect and if/else NDK)
#
#
#
#
?>
  <?cs if:android.whichdoc == "online" ?>

  <p>Welcome Developers! If you are new to the Android SDK, please read the steps below, for an
overview of how to set up the SDK. </p>

  <p>If you're already using the Android SDK, you should
update to the latest tools or platform using the <em>Android SDK and AVD Manager</em>, rather than
downloading a new SDK starter package. See <a
href="<?cs var:toroot ?>sdk/adding-components.html">Adding SDK Components</a>.</p>

  <table class="download">
    <tr>
      <th>Platform</th>
      <th>Package</th>
      <th>Size</th>
      <th>MD5 Checksum</th>
  </tr>
  <tr>
    <td rowspan="2">Windows</td>
    <td>
  <a onclick="onDownload(this)" href="http://dl.google.com/android/<?cs var:sdk.win_download
?>"><?cs var:sdk.win_download ?></a>
    </td>
    <td><?cs var:sdk.win_bytes ?> bytes</td>
    <td><?cs var:sdk.win_checksum ?></td>
  </tr>
  <tr>
    <!-- blank TD from Windows rowspan -->
    <td>
  <a onclick="onDownload(this)" href="http://dl.google.com/android/<?cs var:sdk.win_installer
?>"><?cs var:sdk.win_installer ?></a> (Recommended)
    </td>
    <td><?cs var:sdk.win_installer_bytes ?> bytes</td>
    <td><?cs var:sdk.win_installer_checksum ?></td>
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
  </table>


<div id="next-steps" style="display:none">
  <p><b><em><span id="filename"></span></em> is now downloading. Follow the steps below to
get started.</b></p>
</div>

<script type="text/javascript">
function onDownload(link) {
  $("#filename").text($(link).html());
  $("#next-steps").show();
}
</script>
  <?cs else ?> <?cs # end if online ?>

    <?cs if:sdk.preview ?><?cs # it's preview offline docs ?>
      <p>Welcome developers! We are pleased to provide you with a preview SDK for the upcoming
    Android 3.0 release, to give you a head-start on developing applications for it.
    </p>
    
      <p>See the <a
    href="<?cs var:toroot ?>sdk/preview/start.html">Getting Started</a> document for more information
    about how to set up the preview SDK and get started.</p>
    <style type="text/css">
    .non-preview { display:none; }
    </style>
    
    <?cs else ?><?cs # it's normal offline docs ?>
      <style type="text/css">
        p.offline-message { display:block; }
        p.online-message { display:none; }
      </style>
    <?cs /if ?>
    
  <?cs /if ?> <?cs # end if/else online ?>
  
<?cs /if ?> <?cs # end if/else NDK ?>

<?cs /if ?> <?cs # end if/else redirect ?>

<?cs call:tag_list(root.descr) ?>

</div><!-- end jd-content -->

<?cs if:!sdk.redirect ?>
<?cs include:"footer.cs" ?>
<?cs /if ?>

</div><!-- end g-unit -->

<?cs include:"trailer.cs" ?>

</body>
</html>



