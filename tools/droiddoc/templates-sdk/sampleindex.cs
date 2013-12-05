<?cs include:"doctype.cs" ?>
<?cs include:"macros.cs" ?>
<html<?cs if:devsite ?> devsite<?cs /if ?>>
<?cs include:"head_tag.cs" ?>
<body class="gc-documentation develop samples" itemscope itemtype="http://schema.org/Article">
<?cs include:"header.cs" ?>

<div <?cs if:fullpage
?>class="fullpage"<?cs elif:design||tools||about||sdk||distribute
?>class="col-13" id="doc-col"<?cs else 
?>class="col-12" id="doc-col"<?cs /if ?> >

<!-- start breadcrumb block -->
<div id="api-info-block">
<div class="sum-details-links">

<!-- related links -->
<?cs if:projectStructure ?>
<a href="<?cs var:toroot ?>samples/<?cs var:projectDir ?>/index.html">Overview</a>
&#124; Project<?cs else ?>Overview
&#124; <a href="<?cs var:toroot ?>samples/<?cs var:projectDir ?>/project.html">Project</a>
<?cs /if ?>
&#124; <a href="<?cs var:toroot ?>downloads/samples/<?cs var:projectDir ?>.zip">Download</a>

</div><!-- end sum-details-links -->

</div><!-- end breadcurmb block -->

<h1 itemprop="name"><?cs var:projectDir ?></h1>
  
<div id="jd-content">
<?cs def:display_files(files) ?>

    <?cs each:file = files ?>
        <?cs if:file.Type != "dir" ?>
            <div class="structure-<?cs var:file.Type ?>">
            <a href="<?cs var:toroot ?><?cs var:file.Href ?>"><?cs var:file.Name ?></a>
            </div>
        <?cs else ?>
            <div class="toggle-content opened structure-dir">
               <a href="#" onclick="return toggleContent(this)">
               <img src="<?cs var:toroot ?>assets/images/triangle-opened.png"
                  class="toggle-content-img structure-toggle-img" height="9px" width="9px" />
               <?cs var:file.Name ?></a><?cs 
                  if:file.SummaryFlag == "true" ?><span class="dirInfo"
                    >[&nbsp;<a href="file.SummaryHref">Info</a>&nbsp;]</a></span><?cs 
                  /if ?>
               <div class="toggle-content-toggleme structure-toggleme"> 
            <?cs if:file.Sub.0.Name ?>
                 <?cs call:display_files(file.Sub) ?>
            <?cs /if ?>
               </div> <?cs # /toggleme ?>
            </div> <?cs # /toggle-content ?>
         <?cs /if ?>
    <?cs /each ?>
<?cs /def ?>

<?cs if:android.whichdoc == "online" ?>
  <?cs # If this is the online docs, build the src code navigation links ?>

  <?cs if:projectStructure ?>

    <?cs call:display_files(Files) ?>

  <?cs else ?> <?cs # else not project structure doc ?>

    <?cs var:summary ?>

    <?cs # Remove project structure from landing pages for now
         # <h2>Project Structure</h2>
         # <p>Decide what to do with this ...</p>
         # <?cs call:display_files(Files) ?>

  <?cs /if ?> <?cs # end if projectStructure ?>

<?cs else ?><?cs
  # else, this means it's offline docs,
          so don't show src links (we dont have the pages!) ?>

<?cs /if ?><?cs # end if/else online docs ?>

  </div> <!-- end jd-content -->

<?cs include:"footer.cs" ?>
</div><!-- end doc-content -->

<?cs include:"trailer.cs" ?>

</body>
</html>


