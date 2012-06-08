<?cs include:"doctype.cs" ?>
<?cs include:"macros.cs" ?>
<html>
<?cs include:"head_tag.cs" ?>
<body class="gc-documentation" itemscope itemtype="http://schema.org/Article">
<?cs include:"header.cs" ?>

<div class="g-unit" id="doc-content"><a name="top"></a>

<div id="jd-header" class="guide-header">
  <span class="crumb" itemprop="breadcrumb">
    <?cs if:parent.link ?>
      <a href="<?cs var:parent.link ?>"><?cs var:parent.title ?></a>:
    <?cs else ?>&nbsp;
    <?cs /if ?>
  </span>
<h1 itemprop="name"><?cs var:page.title ?></h1>
</div>

  <?cs # THIS IS THE MAIN DOC CONTENT ?>
  <div id="jd-content">
 
    <?cs if:trainingnavtop ?>
    <div class="training-nav-top">

      <?cs if:next.link ?>
        <?cs if:startpage ?>
        <div class="training-nav-button-next">
          <a href="<?cs var:next.link ?>">
            Get started
            <span style="font-size:1.2em">&rsaquo;</span>
            <span class="training-nav-button-title"><?cs var:next.title ?></span>
          </a>
        </div>

        <?cs else ?><?cs # if not startpage ?>

        <div class="training-nav-button-next">
          <a href="<?cs var:next.link ?>">
            Next lesson
            <span style="font-size:1.2em">&rsaquo;</span>
            <span class="training-nav-button-title"><?cs var:next.title ?></span>
          </a>
        </div>
        <?cs /if ?><?cs # end if/else startpage ?>

      <?cs /if ?><?cs # end if next.link ?>

      <?cs if:previous.link ?>
      <div class="training-nav-button-previous">
        <a href="<?cs var:previous.link ?>">
          <span style="font-size:1.2em">&lsaquo;</span>
          Previous lesson
          <span class="training-nav-button-title"><?cs var:previous.title ?></span>
        </a>
      </div>

      <?cs /if ?><?cs # end if previous.link ?>

    </div><!-- end training-nav-top -->
    <?cs /if ?><?cs # end if trainingnavtop ?>


    <div class="jd-descr" itemprop="articleBody">
    <?cs call:tag_list(root.descr) ?>
    </div>

    <?cs if:!startpage && (previous.link || next.link) ?>
    <div class="training-nav-bottom">
      <?cs if:next.link ?>
      <div class="training-nav-button-next">
        <a href="<?cs var:next.link ?>">
          Next lesson
          <span style="font-size:1.2em">&rsaquo;</span>
          <br/><span class="training-nav-button-title"><?cs var:next.title ?></span>
        </a>
      </div>
      <?cs /if ?>

      <?cs if:previous.link ?>
      <div class="training-nav-button-previous">
        <a href="<?cs var:previous.link ?>">
          <span style="font-size:1.2em">&lsaquo;</span>
          Previous lesson
          <br/><span class="training-nav-button-title"><?cs var:previous.title ?></span>
        </a>
      </div>
      <?cs /if ?>
    </div> <!-- end training-nav -->
    <?cs /if ?>
    
    <a href="#top" style="float:right">&uarr; Go to top</a>
    <?cs if:parent.link ?>
      <p><a href="<?cs var:parent.link ?>">&larr; Back to <?cs var:parent.title ?></a></p>
    <?cs /if ?>

  </div> <!-- end jd-content -->

<?cs include:"footer.cs" ?>
</div><!-- end doc-content -->

<?cs include:"trailer.cs" ?>

</body>
</html>



