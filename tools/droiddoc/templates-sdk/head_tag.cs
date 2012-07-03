<head>
<meta http-equiv="Content-Type" content="text/html; charset=utf-8">
<?cs if:page.metaDescription ?>
<meta name="Description" content="<?cs var:page.metaDescription ?>">
<?cs /if ?>
<link rel="shortcut icon" type="image/x-icon" href="<?cs var:toroot ?>favicon.ico" />
<title><?cs 
  if:page.title ?><?cs 
    var:page.title ?> | <?cs
  /if ?>Android Developers</title>

<!-- BASIC STYLESHEETS -->
<link rel="stylesheet"
href="<?cs if:android.whichdoc != 'online' ?>http:<?cs /if ?>//fonts.googleapis.com/css?family=Roboto:regular,medium,thin,italic,mediumitalic,bold" title="roboto">
<link href="<?cs var:toroot ?>assets/css/default.css" rel="stylesheet" type="text/css">

<?cs if:reference ?>
<!-- alternative FULLSCREEN styles -->
<link href="<?cs var:toroot ?>assets/css/fullscreen.css" rel="stylesheet" class="fullscreen"
type="text/css">
<?cs /if ?>

<?cs if:carousel ?>
<!-- homepage carousel -->
<link href="<?cs var:toroot ?>assets/css/home.css" rel="stylesheet" type="text/css">
<?cs /if ?>

<!-- BASIC JAVASCRIPT -->
<script src="<?cs var:toroot ?>assets/js/global-libraries-combined.js"
        type="text/javascript"></script>
<script type="text/javascript">
  var toRoot = "<?cs var:toroot ?>";
</script>
<script src="<?cs var:toroot ?>assets/js/docs.js" type="text/javascript"></script>

<?cs if:carousel ?>
<!-- homepage carousel -->
<script type="text/javascript" src="<?cs var:toroot ?>assets/js/carousel.js"></script>
<?cs /if ?>

<!-- search -->
<script src="<?cs if:android.whichdoc != 'online' ?>http:<?cs /if ?>//www.google.com/jsapi" type="text/javascript"></script>
<script src="<?cs var:toroot ?>assets/js/search_autocomplete.js" type="text/javascript"></script>

<?cs if:tabbedList ?>
<!-- tabbed lists -->
<script src="<?cs var:toroot ?>assets/js/tabbedlist.js" type="text/javascript"></script>
<?cs /if ?>

<?cs if:reference ?>
<script src="<?cs var:toroot ?>assets/js/droiddoc.js" type="text/javascript"></script>
<?cs /if ?>
<script src="<?cs var:toroot ?>navtree_data.js" type="text/javascript"></script>

</head>