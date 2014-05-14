<head>
<?cs
  ####### If building devsite, add some meta data needed for when generating the top nav ######### ?>
<?cs
  if:devsite ?><?cs
    if:guide||develop||training||reference||tools||sdk||google||samples
      ?><meta name="top_category" value="develop" /><?cs
    elif:google
      ?><meta name="top_category" value="google" /><?cs
    elif:reference && !(reference.gms || reference.gcm)
      ?><meta name="top_category" value="css-fullscreen" /><?cs
    /if ?>
  <?cs
  /if
?><?cs
  # END if/else devsite ?>
<meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
<meta name="viewport" content="width=<?cs
  if:page.viewport_width ?><?cs
    var:page.viewport_width ?><?cs
  else ?>device-width<?cs /if ?>" />
<?cs
  if:page.metaDescription ?>
<meta name="Description" content="<?cs var:page.metaDescription ?>"><?cs
  /if ?>
<link rel="shortcut icon" type="image/x-icon" href="<?cs var:toroot ?>favicon.ico" />
<title><?cs 
  if:page.title ?><?cs 
    var:page.title ?> | <?cs
  /if ?>Android Developers</title>

<!-- STYLESHEETS -->
<link rel="stylesheet"
href="<?cs
if:android.whichdoc != 'online' ?>http:<?cs
/if ?>//fonts.googleapis.com/css?family=Roboto+Condensed">
<link rel="stylesheet" href="<?cs
if:android.whichdoc != 'online' ?>http:<?cs
/if ?>//fonts.googleapis.com/css?family=Roboto:light,regular,medium,thin,italic,mediumitalic,bold"
  title="roboto">
<link href="<?cs var:toroot ?>assets/css/default.css" rel="stylesheet" type="text/css">

<?cs if:reference && !(reference.gms || reference.gcm || wear) ?>
<!-- FULLSCREEN STYLESHEET -->
<link href="<?cs var:toroot ?>assets/css/fullscreen.css" rel="stylesheet" class="fullscreen"
type="text/css">
<?cs /if ?>

<!-- JAVASCRIPT -->
<script src="<?cs if:android.whichdoc != 'online' ?>http:<?cs /if ?>//www.google.com/jsapi" type="text/javascript"></script>
<?cs
if:devsite
  ?><script src="<?cs var:toroot ?>_static/js/android_3p-bundle.js" type="text/javascript"></script><?cs
else
  ?><script src="<?cs var:toroot ?>assets/js/android_3p-bundle.js" type="text/javascript"></script><?cs
/if ?><?cs
  if:page.customHeadTag ?>
<?cs var:page.customHeadTag ?><?cs
  /if ?>
<script type="text/javascript">
  var toRoot = "<?cs var:toroot ?>";
  var metaTags = [<?cs var:meta.tags ?>];
  var devsite = <?cs if:devsite ?>true<?cs else ?>false<?cs /if ?>;
</script>
<script src="<?cs var:toroot ?>assets/js/docs.js" type="text/javascript"></script>

<script type="text/javascript">
  var _gaq = _gaq || [];
  _gaq.push(['_setAccount', 'UA-5831155-1']);
  _gaq.push(['_trackPageview']);

  (function() {
    var ga = document.createElement('script'); ga.type = 'text/javascript'; ga.async = true;
    ga.src = ('https:' == document.location.protocol ? 'https://ssl' : 'http://www') + '.google-analytics.com/ga.js';
    var s = document.getElementsByTagName('script')[0]; s.parentNode.insertBefore(ga, s);
  })();
</script>
</head>
