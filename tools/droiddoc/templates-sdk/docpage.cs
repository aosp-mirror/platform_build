<?cs include:"doctype.cs" ?>
<?cs include:"macros.cs" ?>
<html<?cs if:devsite ?> devsite<?cs /if ?>>
<?cs include:"head_tag.cs" ?>
<body class="gc-documentation <?cs if:(google || reference.gms || reference.gcm) ?>google<?cs /if ?>
  <?cs if:(guide||develop||training||reference||tools||sdk||samples) ?>develop<?cs if:guide ?> guide<?cs /if ?><?cs if:samples ?> samples<?cs /if ?><?cs
  elif:about ?>about<?cs
  elif:design ?>design<?cs
  elif:distribute ?>distribute<?cs
  /if ?><?cs
  if:page.trainingcourse ?> trainingcourse<?cs /if ?>" itemscope itemtype="http://schema.org/Article">
<?cs include:"header.cs" ?>

<div <?cs if:fullpage
?>class="fullpage"<?cs elif:design||tools||about||sdk||distribute
?>class="col-13" id="doc-col"<?cs else 
?>class="col-12" id="doc-col"<?cs /if ?> >

<?cs if:(design||training||walkthru) && !page.trainingcourse && !page.article ?><?cs # header logic for docs that provide previous/next buttons ?>
  <?cs if:header.hide ?>
  <?cs else ?>
  <div class="layout-content-row content-header <?cs if:header.justLinks ?>just-links<?cs /if ?>">
    <div class="layout-content-col <?cs if:training ?>span-7<?cs else ?>span-9<?cs /if ?>">
      <?cs if:header.justLinks ?>&nbsp;
      <?cs else ?><h1 itemprop="name"><?cs var:page.title ?></h1>
      <?cs /if ?>
    </div>
    <?cs if:training ?>
      <div class="training-nav-top layout-content-col span-5" itemscope itemtype="http://schema.org/SiteNavigationElement">
        <a href="#" class="prev-page-link hide"
            zh-tw-lang="上一堂課"
            zh-cn-lang="上一课"
            ru-lang="Предыдущий"
            ko-lang="이전"
            ja-lang="前へ"
            es-lang="Anterior"               
            >Previous</a>
        <a href="#" class="next-page-link hide"
            zh-tw-lang="下一堂課"
            zh-cn-lang="下一课"
            ru-lang="Следующий"
            ko-lang="다음"
            ja-lang="次へ"
            es-lang="Siguiente"               
            >Next</a>
        <a href="#" class="start-class-link hide"
            zh-tw-lang="開始上課"
            zh-cn-lang="开始"
            ru-lang="Начало работы"
            ko-lang="시작하기"
            ja-lang="開始する"
            es-lang="Empezar"               
            >Get started</a>
      </div>
    <?cs elif:!page.trainingcourse ?>
      <div class="paging-links layout-content-col span-4" itemscope itemtype="http://schema.org/SiteNavigationElement">
        <a href="#" class="prev-page-link hide"
            zh-tw-lang="上一堂課"
            zh-cn-lang="上一课"
            ru-lang="Предыдущий"
            ko-lang="이전"
            ja-lang="前へ"
            es-lang="Anterior"               
            >Previous</a>
        <a href="#" class="next-page-link hide"
            zh-tw-lang="下一堂課"
            zh-cn-lang="下一课"
            ru-lang="Следующий"
            ko-lang="다음"
            ja-lang="次へ"
            es-lang="Siguiente"               
            >Next</a>
      </div>
    <?cs /if ?><?cs # end if training ?>
  </div>
  <?cs /if ?>
<?cs else ?>
  <?cs if:(!fullpage && !header.hide) ?>
    <?cs if:page.landing ?><?cs # header logic for docs that are landing pages ?>
      <div class="landing-banner">
        <?cs if:page.landing.image ?><?cs # use two-column layout only if there's an image ?>
        <div class="col-6">
          <img src="<?cs var:toroot ?><?cs var:page.landing.image ?>" alt="" />
        </div>
        <div class="col-6">
        <?cs /if ?>
          <h1 itemprop="name" style="margin-bottom:0;"><?cs var:page.title ?></h1>
          <p itemprop="description"><?cs var:page.landing.intro ?></p>
          
          <p><a class="next-page-link topic-start-link"></a></p>
        <?cs if:page.landing.image ?>
        </div>
        <?cs /if ?>
      </div>
    <?cs else ?>
      <?cs if:tab1 ?><div id="title-tabs-wrapper"><?cs /if ?>
        <h1 itemprop="name" <?cs if:tab1 ?>class="with-title-tabs"<?cs /if ?>><?cs var:page.title ?></h1><?cs
          if:tab1 ?><ul id="title-tabs">
              <li class="selected"><a href="<?cs var:tab1.link ?>"><?cs var:tab1 ?></a></li>
              <?cs if:tab2 ?>
              <li><a href="<?cs var:tab2.link ?>"><?cs var:tab2 ?></a></li><?cs /if ?>
              <?cs if:tab3 ?>
              <li><a href="<?cs var:tab3.link ?>"><?cs var:tab3 ?></a></li><?cs /if ?>
            </ul>
          <?cs /if ?>
      <?cs if:tab1 ?></div><!-- end tab-wrapper --><?cs /if ?>
    <?cs /if ?>
  <?cs /if ?>
<?cs /if ?><?cs # end if design ?>

  <?cs # THIS IS THE MAIN DOC CONTENT ?>
  <div id="jd-content">


    <div class="jd-descr" itemprop="articleBody">
    <?cs call:tag_list(root.descr) ?>
    </div>
      
      <div class="content-footer <?cs 
                    if:fullpage ?>wrap<?cs
                    else ?>layout-content-row<?cs /if ?>" 
                    itemscope itemtype="http://schema.org/SiteNavigationElement">
        <div class="layout-content-col <?cs 
                    if:fullpage ?>col-16<?cs 
                    elif:training||guide ?>col-8<?cs 
                    else ?>col-9<?cs /if ?>" style="padding-top:4px">
          <?cs if:!page.noplus ?><?cs if:fullpage ?><style>#___plusone_0 {float:right !important;}</style><?cs /if ?>
            <div class="g-plusone" data-size="medium"></div>
          <?cs /if ?>
        </div>
        <?cs if:!fullscreen ?>
        <div class="paging-links layout-content-col col-4">
          <?cs if:(design||training||walkthru) && !page.landing && !page.trainingcourse && !footer.hide ?>
            <a href="#" class="prev-page-link hide"
                zh-tw-lang="上一堂課"
                zh-cn-lang="上一课"
                ru-lang="Предыдущий"
                ko-lang="이전"
                ja-lang="前へ"
                es-lang="Anterior"               
                >Previous</a>
            <a href="#" class="next-page-link hide"
                zh-tw-lang="下一堂課"
                zh-cn-lang="下一课"
                ru-lang="Следующий"
                ko-lang="다음"
                ja-lang="次へ"
                es-lang="Siguiente"               
                >Next</a>
          <?cs /if ?>
        </div>
        <?cs /if ?>
      </div>
      
      <?cs # for training classes, provide a different kind of link when the next page is a different class ?>
      <?cs if:training && !page.article ?>
      <div class="layout-content-row content-footer next-class" style="display:none" itemscope itemtype="http://schema.org/SiteNavigationElement">
          <a href="#" class="next-class-link hide">Next class: </a>
      </div>
      <?cs /if ?>

  </div> <!-- end jd-content -->

<?cs include:"footer.cs" ?>
</div><!-- end doc-content -->

<?cs include:"trailer.cs" ?>

</body>
</html>



