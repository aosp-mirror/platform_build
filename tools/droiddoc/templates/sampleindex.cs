<?cs include:"doctype.cs" ?>
<?cs include:"macros.cs" ?>
<?cs set:resources="true" ?>
<html>
<?cs include:"head_tag.cs" ?>
<?cs include:"header.cs" ?>
<body class="gc-documentation">


<a name="top"></a>
<div class="g-unit" id="doc-content">
 <div id="jd-header" class="guide-header">
  <span class="crumb">&nbsp;</span>
  <h1><?cs var:page.title ?></h1>
 </div>

<div id="jd-content">

<?cs var:summary ?>

<?cs if:android.whichdoc == "online" ?><?cs
  # If this is the online docs, build the src code navigation links ?>

  <?cs if:subcount(subdirs) ?>
      <h2>Subdirectories</h2>
      <ul class="nolist">
      <?cs each:dir=subdirs ?>
        <li><a href="<?cs var:dir.name ?>/index.html"><?cs
          var:dir.name ?>/</a></li>
      <?cs /each ?>
      </ul>
  <?cs /if ?>

  <?cs if:subcount(files) ?>
      <h2>Files</h2>
      <ul class="nolist">
      <?cs each:file=files ?>
        <li><a href="<?cs var:file.href ?>"><?cs
          var:file.name ?></a></li>
      <?cs /each ?>
      </ul>
  <?cs /if ?>

<?cs else ?><?cs
  # else, this means it's offline docs,
          so don't show src links (we don't have the pages!) ?>

<p>You can find the source code for this sample in your SDK at:</p>
<p style="margin-left:2em">
<code><em>&lt;sdk&gt;</em>/platforms/android-<em>&lt;version&gt;</em>/samples/</code>
</p>

<?cs /if ?><?cs # end if/else online docs ?>

</div><!-- end jd-content -->

<?cs include:"footer.cs" ?>

</div><!-- end doc-content -->

<?cs include:"trailer.cs" ?>

</body>
</html>
