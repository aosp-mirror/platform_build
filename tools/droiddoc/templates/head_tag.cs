<head>
<meta http-equiv="Content-Type" content="text/html; charset=utf-8">
<title><?cs var:page.title ?> | <?cs 
        if:guide ?>Guide | <?cs 
        elif:reference ?>Reference | <?cs 
        elif:sdk ?>SDK | <?cs 
        elif:sample ?>Samples | <?cs 
        /if ?>Android Developers</title>

<?cs if:guide ?>
<link href="<?cs var:toroot ?>assets/android-developer-docs-devguide.css" rel="stylesheet" type="text/css" />
<?cs else ?>
<link href="<?cs var:toroot ?>assets/android-developer-docs.css" rel="stylesheet" type="text/css" />
<?cs /if ?>
<script src="<?cs var:toroot ?>assets/search_autocomplete.js"></script>
<script src="<?cs var:toroot ?>reference/lists.js"></script>
<script src="<?cs var:toroot ?>assets/jquery-resizable.min.js"></script>
<script src="<?cs var:toroot ?>assets/android-developer-docs.js"></script>
<script>
  setToRoot("<?cs var:toroot ?>");
</script>

<script src="<?cs var:toroot ?>navtree_data.js"></script>
<script src="<?cs var:toroot ?>assets/navtree.js"></script>


<noscript>
  <style>
    body{overflow:auto;}
    #body-content{position:relative; top:0;}
    #doc-content{overflow:visible;border-left:3px solid #666;}
    #side-nav{padding:0;}
    #side-nav .toggle-list ul {display:block;}
    #resize-packages-nav{border-bottom:3px solid #666;}
  </style>
</noscript>
</head>
