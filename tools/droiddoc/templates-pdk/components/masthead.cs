<?cs 
def:custom_masthead() ?>
  <div id="header">
      <div id="headerLeft">
          <a href="<?cs var:toroot?>" tabindex="-1"><img
              src="<?cs var:toroot ?>assets/images/open_source.png" alt="Android Open Source Project" /></a>
          <ul class="<?cs if:home ?>home<?cs
                      elif:doc.type == "source" ?>source<?cs
                      elif:doc.type == "porting" ?>porting<?cs
                      elif:doc.type == "compatibility" ?>compatibility<?cs
                      elif:doc.type == "community" ?>community<?cs
                      elif:doc.type == "about" ?>about<?cs /if ?>">
              <li id="home-link"><a href="<?cs var:toroot ?>index.html"><span>Home</span></a></li>
              <li id="source-link"><a href="<?cs var:toroot ?>source/index.html"
                                  onClick="return loadLast('source')"><span>Source</span></a></li>
              <li id="porting-link"><a href="<?cs var:toroot ?>porting/index.html"
                                  onClick="return loadLast('porting')"><span>Porting</span></a></li>
              <li id="compatibility-link"><a href="<?cs var:toroot ?>compatibility/index.html"
                                  onClick="return loadLast('compatibility')"><span>Compatibility</span></a></li>
              <li id="community-link"><a href="<?cs var:toroot ?>community/index.html"
                                  onClick="return loadLast('community')"><span>Community</span></a></li>
              <li id="about-link"><a href="<?cs var:toroot ?>about/index.html"
                                  onClick="return loadLast('about')"><span>About</span></a></li>
          </ul> 
      </div>
      <div id="headerRight">
          <div id="headerLinks">
            <!-- <img src="<?cs var:toroot ?>assets/images/icon_world.jpg" alt="" /> -->
            <span class="text">
              <!-- &nbsp;<a href="#">English</a> | -->
              <a href="http://www.android.com">Android.com</a>
            </span>
          </div>
      </div><!-- headerRight -->
  </div><!-- header --><?cs 
/def ?><?cs # custom_masthead ?>
