<?cs def:custom_masthead() ?>
  <div id="header">
      <div id="headerLeft">
          <a href="<?cs var:toroot ?>index.html" tabindex="-1"><img
              src="<?cs var:toroot ?>assets/images/bg_logo.png" alt="Android Developers" /></a>
          <?cs include:"header_tabs.cs" ?>     <?cs # The links are extracted so we can better manage localization ?>
      </div>
      <div id="headerRight">
          <div id="headerLinks">
          <?cs if:template.showLanguageMenu ?>
            <img src="<?cs var:toroot ?>assets/images/icon_world.jpg" alt="Language:" /> 
            <span id="language">
             	<select name="language" onChange="changeLangPref(this.value, true)">
          			<option value="en">English&nbsp;&nbsp;&nbsp;</option>
          			<option value="ja">日本語</option>
          			<?cs # 
      			    <option value="de">Deutsch</option> 
          			<option value="es">Español</option>
          			<option value="fr">Français</option>
          			<option value="it">Italiano</option>
          			<option value="zh-CN">中文 (简体)</option>
          			<option value="zh-TW">中文 (繁體)</option>
      			    ?>
             	</select>	
             	<script type="text/javascript">
             	  <!--  
                  loadLangPref();  
             	   //-->
             	</script>
            </span>
          <?cs /if ?>&nbsp;&nbsp;
          <a href="<?cs var:toroot ?>design/index.html">Android Design</a>&nbsp;&nbsp;
          <a href="http://www.android.com">Android.com</a>
          </div><?cs 
          call:default_search_box() ?><?cs 
    	 	  if:reference ?>
    			  <div id="api-level-toggle">
    			    <input type="checkbox" id="apiLevelCheckbox" onclick="toggleApiLevelSelector(this)" />
    			    <label for="apiLevelCheckbox" class="disabled">Filter by API Level: </label>
    			    <select id="apiLevelSelector">
    			      <!-- option elements added by buildApiLevelSelector() -->
    			    </select>
    			  </div>
    	 	    <script>
              var SINCE_DATA = [ <?cs 
                each:since = since ?>'<?cs 
                  var:since.name ?>'<?cs 
                  if:!last(since) ?>, <?cs /if ?><?cs
                /each 
              ?> ];
              buildApiLevelSelector();
            </script><?cs 
    			/if ?>
      </div><!-- headerRight -->
      <script type="text/javascript">
        <!--  
        changeTabLang(getLangPref());
        //-->
      </script>
  </div><!-- header --><?cs 
/def ?>