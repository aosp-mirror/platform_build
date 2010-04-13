<head>
<meta http-equiv="Content-Type" content="text/html; charset=utf-8">
<link rel="shortcut icon" type="image/x-icon" href="<?cs var:toroot ?>assets/favicon.ico" />
<title><?cs 
  if:page.title ?><?cs 
    var:page.title ?><?cs
    if:sdk.version ?> (<?cs
      var:sdk.version ?>)<?cs
    /if ?> | <?cs
  /if ?>Android Open Source</title>
<link href="<?cs var:toroot ?>assets/android-developer-docs-devguide.css" rel="stylesheet" type="text/css" />
<!-- <link href="<?cs var:toroot ?>assets-pdk/pdk-local.css" rel="stylesheet" type="text/css" /> -->
<script src="<?cs var:toroot ?>assets/search_autocomplete.js" type="text/javascript"></script>
<script src="<?cs var:toroot ?>assets/jquery-resizable.min.js" type="text/javascript"></script>
<script src="<?cs var:toroot ?>assets/android-developer-docs.js" type="text/javascript"></script>
<script type="text/javascript">
  setToRoot("<?cs var:toroot ?>");
</script>
<script type="text/javascript">
  function resizeDoxFrameHeight() {
	if(document.getElementById && !(document.all)) {
		height= document.getElementById('doxygen').contentDocument.body.scrollHeight + 20;
		document.getElementById('doxygen').style.height = height+"pt";
	}
	else if(document.all) {
		height= document.frames('doxygen').document.body.scrollHeight + 20;
		document.all.doxygen.style.height = height;
	}
}
</script>
<script type="text/javascript">
  jQuery(document).ready(function() {
        jQuery("pre").addClass("prettyprint");
  });
</script>
<noscript>
  <style type="text/css">
    body{overflow:auto;}
    #body-content{position:relative; top:0;}
    #doc-content{overflow:visible;border-left:3px solid #666;}
    #side-nav{padding:0;}
    #side-nav .toggle-list ul {display:block;}
    #resize-packages-nav{border-bottom:3px solid #666;}
  </style>
</noscript>
</head>
