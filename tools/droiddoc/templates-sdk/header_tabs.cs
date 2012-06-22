
<!-- CURRENTLY NOT USED... ALL TABS ARE IN masthead.cs -->

<ul id="header-tabs" class="<?cs 
	if:reference ?>reference<?cs
	elif:guide ?>guide<?cs
	elif:sdk ?>sdk<?cs
	elif:home ?>home<?cs
	elif:resources ?>resources<?cs
	elif:training ?>training<?cs
	elif:tools ?>tools<?cs
	elif:videos ?>videos<?cs /if ?>">
    
	<li id="sdk-link"><a href="<?cs var:toroot ?>design/index.html">
		<span class="en">Design</span>
	</a></li>
	<li id="sdk-link"><a href="<?cs var:toroot ?>develop/index.html">
		<span class="en">Develop</span>
	</a></li>
	<li id="sdk-link"><a href="<?cs var:toroot ?>distribute/index.html">
		<span class="en">Distribute</span>
	</a></li>
</ul>
	
	
	
	
	
	
	
	
<!--	
	<li id="guide-link"><a href="<?cs var:toroot ?>guide/index.html" onClick="return loadLast('guide')">
	<?cs if:!sdk.redirect ?>
		<span class="en">Guide</span>
		<span style="display:none" class="de">Handbuch</span>
		<span style="display:none" class="es">Guía</span>
		<span style="display:none" class="fr">Guide</span>
		<span style="display:none" class="it">Guida</span>
		<span style="display:none" class="ja">開発ガイド</span>
		<span style="display:none" class="zh-CN">开发人员指南</span>
		<span style="display:none" class="zh-TW">開發指南</span>
	<?cs /if ?>
	</a></li>
-->



     
</ul>
