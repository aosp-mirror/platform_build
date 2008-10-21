[include "/android/_local_variables.ezt"]
[define page_title]<?cs var:page.title ?>[end]

  <head>
    [include "/html/apis/_common_head_elements.ezt"]
    <script src="<?cs var:toroot ?>assets/search_autocomplete.js"></script>
    <link rel="stylesheet" type="text/css" href="/css/semantic_headers.css" />
    <link rel="stylesheet" type="text/css" href="<?cs var:toroot ?>assets/style.css" />
    <script>
    jQuery(document).ready(function() {
            jQuery("pre").addClass("prettyprint");
        });
    </script>

  </head>
