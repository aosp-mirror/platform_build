<ul id="header-tabs" class="<?cs 
	if:reference ?>reference<?cs
	elif:guide ?>guide<?cs
	elif:sdk ?>sdk<?cs
	elif:home ?>home<?cs
	elif:community ?>community<?cs
	elif:videos ?>videos<?cs /if ?>">
    
	<li id="home-link"><a href="<?cs var:toroot ?><?cs 
	                            if:android.whichdoc != "online" ?>offline.html<?cs 
	                            else ?>index.html<?cs /if ?>">
	<?cs if:!sdk.redirect ?>
		<span class="en">Home</span>
		<span style="display:none" class="de">Startseite</span>
		<span style="display:none" class="es"></span>
		<span style="display:none" class="fr"></span>
		<span style="display:none" class="it"></span>
    <span style="display:none" class="ja">ホーム</span>
		<span style="display:none" class="zh-CN">主页</span>
		<span style="display:none" class="zh-TW">首頁</span>
	<?cs /if ?>
	</a></li>
	<li id="sdk-link"><a href="<?cs var:toroot ?>sdk/index.html">
		<span class="en">SDK</span>
	</a></li>
	<li id="guide-link"><a href="<?cs var:toroot ?>guide/index.html" onClick="return loadLast('guide')">
	<?cs if:!sdk.redirect ?>
		<span class="en">Dev Guide</span>
		<span style="display:none" class="de">Handbuch</span>
		<span style="display:none" class="es">Guía</span>
		<span style="display:none" class="fr">Guide</span>
		<span style="display:none" class="it">Guida</span>
    <span style="display:none" class="ja">開発ガイド</span>
		<span style="display:none" class="zh-CN">开发人员指南</span>
		<span style="display:none" class="zh-TW">開發指南</span>
	<?cs /if ?>
	</a></li>
	<li id="reference-link"><a href="<?cs var:toroot ?>reference/packages.html" onClick="return loadLast('reference')">
	<?cs if:!sdk.redirect ?>
		<span class="en">Reference</span>
		<span style="display:none" class="de">Referenz</span>
		<span style="display:none" class="es">Referencia</span>
		<span style="display:none" class="fr">Référence</span>
		<span style="display:none" class="it">Riferimento</span>
    <span style="display:none" class="ja">リファレンス</span>
		<span style="display:none" class="zh-CN">参考</span>
		<span style="display:none" class="zh-TW">參考資料</span>
	<?cs /if ?>
	</a></li>
	<li><a href="http://android-developers.blogspot.com" onClick="return requestAppendHL(this.href)">
	<?cs if:!sdk.redirect ?>
		<span class="en">Blog</span>
		<span style="display:none" class="de"></span>
		<span style="display:none" class="es"></span>
		<span style="display:none" class="fr"></span>
		<span style="display:none" class="it"></span>
    <span style="display:none" class="ja">ブログ</span>
		<span style="display:none" class="zh-CN">博客</span>
		<span style="display:none" class="zh-TW">網誌</span>
	<?cs /if ?>
	</a></li>
	<li id="videos-link"><a href="<?cs var:toroot ?>videos/index.html" onClick="return loadLast('videos')">
	<?cs if:!sdk.redirect ?>
		<span class="en">Videos</span>
		<span style="display:none" class="de"></span>
		<span style="display:none" class="es"></span>
		<span style="display:none" class="fr"></span>
		<span style="display:none" class="it"></span>
    <span style="display:none" class="ja">ビデオ</span>
		<span style="display:none" class="zh-CN"></span>
		<span style="display:none" class="zh-TW"></span>
	<?cs /if ?>
	</a></li>
	<li id="community-link"><a href="<?cs var:toroot ?>community/index.html">
	<?cs if:!sdk.redirect ?>
		<span class="en">Community</span>
		<span style="display:none" class="de"></span>
		<span style="display:none" class="es">Comunidad</span>
		<span style="display:none" class="fr">Communauté</span>
		<span style="display:none" class="it"></span>
    <span style="display:none" class="ja">コミュニティ</span>
		<span style="display:none" class="zh-CN">社区</span>
		<span style="display:none" class="zh-TW">社群</span>
	<?cs /if ?>
	</a></li>
     
</ul>
