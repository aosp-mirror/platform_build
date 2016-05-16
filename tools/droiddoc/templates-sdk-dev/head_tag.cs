<head>
<?cs
  ####### If building devsite, add some meta data needed for when generating the top nav ######### ?>
  <?cs
    if:devsite ?>
    <meta name="top_category" value="<?cs
      if:ndk ?>ndk<?cs
      elif:(guide||develop||training||reference||tools||sdk||google||reference.gms||reference.gcm||samples) ?>develop<?cs
      elif:(topic||libraries||instantapps) ?>develop<?cs
      elif:(distribute||googleplay||essentials||users||engage||monetize||disttools||stories||analyze) ?>distribute<?cs
      elif:(design||vision||material||patterns||devices||designdownloads) ?>design<?cs
      elif:(about||versions||wear||tv||auto) ?>about<?cs
      elif:wearpreview ?>about<?cs
      elif:work ?>about<?cs
      elif:preview ?>preview<?cs
      else ?>none<?cs
      /if ?>" />
    <?cs set:dac_subcategory_set = #1 ?>
    <meta name="subcategory" value="<?cs
      if:ndk ?><?cs
        if:guide ?>guide<?cs
        elif:samples ?>samples<?cs
          if:(samplesDocPage&&!samplesProjectIndex) ?> samples-docpage<?cs /if ?><?cs
        elif:reference ?>reference<?cs
        elif:downloads ?>downloads<?cs
        else ?>none<?cs set:dac_subcategory_set = #0 ?><?cs /if ?><?cs
      else ?><?cs
        if:(guide||develop||training||reference||tools||sdk||samples) ?><?cs
          if:guide ?>guide<?cs
          elif:training ?><?cs
            if:page.trainingcourse ?>trainingcourse<?cs
            else ?>training<?cs /if ?><?cs
          elif:reference ?>reference<?cs
          elif:samples ?>samples<?cs
            if:(samplesDocPage&&!samplesProjectIndex) ?> samples-docpage<?cs /if ?><?cs
          else ?>none<?cs set:dac_subcategory_set = #0 ?><?cs /if ?><?cs
        elif:(google||reference.gms||reference.gcm) ?>google<?cs
        elif:(topic||libraries) ?><?cs
          if:libraries ?>libraries<?cs
          elif:instantapps ?>instantapps<?cs
          else ?>none<?cs set:dac_subcategory_set = #0 ?><?cs /if ?><?cs
        elif:(distribute||googleplay||essentials||users||engage||monetize||disttools||stories||analyze) ?><?cs
          if:googleplay ?>googleplay<?cs
          elif:essentials ?>essentials<?cs
          elif:users ?>users<?cs
          elif:engage ?>engage<?cs
          elif:monetize ?>monetize<?cs
          elif:disttools ?>disttools<?cs
          elif:stories ?>stories<?cs
          elif:analyze ?>analyze<?cs
          else ?>none<?cs set:dac_subcategory_set = #0 ?><?cs /if ?><?cs
        elif:(about||versions||wear||tv||auto) ?>about<?cs
        elif:preview ?>preview<?cs
        elif:wearpreview ?>wear<?cs
        elif:work ?>work<?cs
        elif:design ?>design<?cs
        elif:walkthru ?>walkthru<?cs
        else ?>none<?cs set:dac_subcategory_set = #0 ?><?cs /if ?><?cs
      /if ?>" />

    <?cs if:nonavpage ?>
      <meta name="hide_toc" value='True' />
    <?cs elif: !nonavpage && dac_subcategory_set && !tools && !sdk ?>
      <meta name="book_path" value="<?cs
        if:ndk ?>/ndk<?cs
          if:guide ?>/guides<?cs
          elif:samples ?>/samples<?cs
          elif:reference ?>/reference<?cs
          elif:downloads ?>/downloads<?cs /if ?><?cs
        else ?><?cs
          if:(guide||develop||training||reference||tools||sdk||samples) ?><?cs
            if:guide ?>/guide<?cs
            elif:training ?>/training<?cs
            elif:reference ?>/reference<?cs
            elif:samples ?>/samples<?cs /if ?><?cs
          elif:(google||reference.gms||reference.gcm) ?>/google<?cs
          elif:(topic||libraries) ?>/topic<?cs
            if:libraries ?>/libraries<?cs
            elif:instantapps ?>/instant-apps<?cs /if ?><?cs
          elif:(distribute||googleplay||essentials||users||engage||monetize||disttools||stories||analyze) ?>/distribute<?cs
            if:googleplay ?>/googleplay<?cs
            elif:essentials ?>/essentials<?cs
            elif:users ?>/users<?cs
            elif:engage ?>/engage<?cs
            elif:monetize ?>/monetize<?cs
            elif:disttools ?>/disttools<?cs
            elif:stories ?>/stories<?cs
            elif:analyze ?>/analyze<?cs /if ?><?cs
          elif:(about||versions||wear||tv||auto) ?>/about<?cs
          elif:preview ?>/preview<?cs
          elif:wearpreview ?>/wear/preview<?cs
          elif:work ?>/work<?cs
          elif:design ?>/design<?cs
          elif:reference.testSupport ?>/reference/android/support/test<?cs
          elif:reference.wearableSupport ?>/reference/android/support/wearable<?cs
          elif:walkthru ?>/walkthru<?cs /if ?><?cs
        /if ?>/_book.yaml" />
    <?cs /if ?>

    <?cs if:page.tags && page.tags != "" ?>
      <meta name="keywords" value='<?cs var:page.tags ?>' />
    <?cs /if ?>

    <?cs if:meta.tags && meta.tags != "" ?>
      <meta name="meta_tags" value='<?cs var:meta.tags ?>' />
    <?cs /if ?>

    <?cs if:fullpage ?>
      <meta name="full_width" value="True" />
    <?cs /if ?>

    <?cs if:page.landing ?>
      <meta name="page_type" value="landing" />
    <?cs /if ?>

    <?cs if:page.article ?>
      <meta name="page_type" value="article" />
    <?cs /if ?>

    <?cs /if ?><?cs
    # END if/else devsite ?>
<?cs
  if:!devsite ?>
<meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
<meta name="viewport" content="width=device-width,initial-scale=1.0,minimum-scale=1.0,maximum-scale=1.0,user-scalable=no" />
<meta content="IE=edge" http-equiv="X-UA-Compatible">
<link rel="shortcut icon" type="image/x-icon" href="<?cs var:toroot ?>favicon.ico" />
<link rel="alternate" href="http://developer.android.com/<?cs var:path.canonical ?>" hreflang="en" />
<link rel="alternate" href="http://developer.android.com/intl/es/<?cs var:path.canonical ?>" hreflang="es" />
<link rel="alternate" href="http://developer.android.com/intl/id/<?cs var:path.canonical ?>" hreflang="id" />
<link rel="alternate" href="http://developer.android.com/intl/ja/<?cs var:path.canonical ?>" hreflang="ja" />
<link rel="alternate" href="http://developer.android.com/intl/ko/<?cs var:path.canonical ?>" hreflang="ko" />
<link rel="alternate" href="http://developer.android.com/intl/pt-br/<?cs var:path.canonical ?>" hreflang="pt-br" />
<link rel="alternate" href="http://developer.android.com/intl/ru/<?cs var:path.canonical ?>" hreflang="ru" />
<link rel="alternate" href="http://developer.android.com/intl/vi/<?cs var:path.canonical ?>" hreflang="vi" />
<link rel="alternate" href="http://developer.android.com/intl/zh-cn/<?cs var:path.canonical ?>" hreflang="zh-cn" />
<link rel="alternate" href="http://developer.android.com/intl/zh-tw/<?cs var:path.canonical ?>" hreflang="zh-tw" />
<?cs /if ?><?cs
# END if/else !devsite ?>

<title><?cs
if:devsite ?><?cs
  if:page.title ?><?cs
    var:html_strip(page.title) ?><?cs
  else ?>Android Developers<?cs
  /if ?><?cs
else ?><?cs
  if:page.title ?><?cs
    var:page.title ?> | <?cs
  /if ?>Android Developers
<?cs /if ?><?cs
# END if/else devsite ?></title>
<?cs
  if:page.metaDescription ?>
<meta name="description" content="<?cs var:page.metaDescription ?>"><?cs
  /if ?>
<?cs
  if:!devsite ?>
<!-- STYLESHEETS -->
<link rel="stylesheet"
href="<?cs
if:android.whichdoc != 'online' ?>http:<?cs
/if ?>//fonts.googleapis.com/css?family=Roboto+Condensed">
<link rel="stylesheet" href="<?cs
if:android.whichdoc != 'online' ?>http:<?cs
/if ?>//fonts.googleapis.com/css?family=Roboto:light,regular,medium,thin,italic,mediumitalic,bold"
  title="roboto">
<?cs
  if:ndk ?><link rel="stylesheet" href="<?cs
  if:android.whichdoc != 'online' ?>http:<?cs
  /if ?>//fonts.googleapis.com/css?family=Roboto+Mono:400,500,700" title="roboto-mono" type="text/css"><?cs
/if ?>
<link href="<?cs var:toroot ?>assets/css/default.css?v=16" rel="stylesheet" type="text/css">

<!-- JAVASCRIPT -->
<script src="<?cs if:android.whichdoc != 'online' ?>http:<?cs /if ?>//www.google.com/jsapi" type="text/javascript"></script>
<script src="<?cs var:toroot ?>assets/js/android_3p-bundle.js" type="text/javascript"></script><?cs
  if:page.customHeadTag ?>
<?cs var:page.customHeadTag ?><?cs
  /if ?>
<script type="text/javascript">
  var toRoot = "<?cs var:toroot ?>";
  var metaTags = [<?cs var:meta.tags ?>];
  var devsite = <?cs if:devsite ?>true<?cs else ?>false<?cs /if ?>;
  var useUpdatedTemplates = <?cs if:useUpdatedTemplates ?>true<?cs else ?>false<?cs /if ?>;
</script>
<script src="<?cs var:toroot ?>assets/js/docs.js?v=17" type="text/javascript"></script>

<script>
  (function(i,s,o,g,r,a,m){i['GoogleAnalyticsObject']=r;i[r]=i[r]||function(){
  (i[r].q=i[r].q||[]).push(arguments)},i[r].l=1*new Date();a=s.createElement(o),
  m=s.getElementsByTagName(o)[0];a.async=1;a.src=g;m.parentNode.insertBefore(a,m)
  })(window,document,'script','//www.google-analytics.com/analytics.js','ga');

  ga('create', 'UA-5831155-1', 'android.com');
  ga('create', 'UA-49880327-2', 'android.com', {'name': 'universal'});  // New tracker);
  ga('send', 'pageview');
  ga('universal.send', 'pageview'); // Send page view for new tracker.
</script>
<?cs /if ?><?cs
# END if/else !devsite ?>
</head>
