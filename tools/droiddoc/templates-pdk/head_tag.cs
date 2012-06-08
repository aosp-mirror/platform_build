<head>
<meta http-equiv="Content-Type" content="text/html; charset=utf-8">
<?cs if:page.metaDescription ?>
<meta name="Description" content="<?cs var:page.metaDescription ?>">
<?cs /if ?>
<link rel="shortcut icon" type="image/x-icon" href="<?cs var:toroot ?>favicon.ico" />
<title><?cs 
  if:page.title ?><?cs 
    var:page.title ?> | <?cs
  /if ?>Android Developers</title><?cs 
if:guide||sdk||resources ?>
<link href="<?cs var:toroot ?>assets/android-developer-docs-devguide.css" rel="stylesheet" type="text/css" /><?cs 
else ?>
<link href="<?cs var:toroot ?>assets/android-developer-docs.css" rel="stylesheet" type="text/css" /><?cs 
/if ?>
<script src="<?cs var:toroot ?>assets/search_autocomplete.js" type="text/javascript"></script>
<script src="<?cs var:toroot ?>assets/jquery-resizable.min.js" type="text/javascript"></script>
<script src="<?cs var:toroot ?>assets/android-developer-docs.js" type="text/javascript"></script>
<script src="<?cs var:toroot ?>assets/prettify.js" type="text/javascript"></script>
<script type="text/javascript">
  setToRoot("<?cs var:toroot ?>");
</script><?cs 
if:reference ?>
<script src="<?cs var:toroot ?>assets/android-developer-reference.js" type="text/javascript"></script>
<script src="<?cs var:toroot ?>navtree_data.js" type="text/javascript"></script><?cs 
/if ?><?cs 
if:resources ?>
<script src="<?cs var:toroot ?>resources/resources-data.js" type="text/javascript"></script><?cs 
/if ?>
<noscript>
  <style type="text/css">
    html,body{overflow:auto;}
    #body-content{position:relative; top:0;}
    #doc-content{overflow:visible;border-left:3px solid #666;}
    #side-nav{padding:0;}
    #side-nav .toggle-list ul {display:block;}
    #resize-packages-nav{border-bottom:3px solid #666;}
  </style>
</noscript>
</head>