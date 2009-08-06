<ul id="header-tabs" class="<?cs 
	if:reference ?>reference<?cs
	elif:guide ?>guide<?cs
	elif:sdk ?>sdk<?cs
	elif:home ?>home<?cs
	elif:community ?>community<?cs
	elif:videos ?>videos<?cs /if ?>">
         
	<li id="home-link"><a href="<?cs var:toroot ?><?cs if:android.whichdoc != "online" ?>offline.html<?cs else ?>index.html<?cs /if ?>">
	<?cs if:!sdk.redirect ?>
		<span class="en">Home</span>
		<span class="de">Startseite</span>
		<span class="es"></span>
		<span class="fr"></span>
		<span class="it"></span>
                <span class="ja">ホーム</span>
		<span class="zh-CN">主页</span>
		<span class="zh-TW">首頁</span>
	<?cs /if ?>
	</a></li>
	<li id="sdk-link"><a href="<?cs var:toroot ?>sdk/<?cs var:sdk.current ?>/index.html">
		<span class="en">SDK</span>
	</a></li>
	<li id="guide-link"><a href="<?cs var:toroot ?>guide/index.html" onClick="return loadLast('guide')">
	<?cs if:!sdk.redirect ?>
		<span class="en">Dev Guide</span>
		<span class="de">Handbuch</span>
		<span class="es">Guía</span>
		<span class="fr">Guide</span>
		<span class="it">Guida</span>
                <span class="ja">開発ガイド</span>
		<span class="zh-CN">开发人员指南</span>
		<span class="zh-TW">開發指南</span>
	<?cs /if ?>
	</a></li>
	<li id="reference-link"><a href="<?cs var:toroot ?>reference/packages.html" onClick="return loadLast('reference')">
	<?cs if:!sdk.redirect ?>
		<span class="en">Reference</span>
		<span class="de">Referenz</span>
		<span class="es">Referencia</span>
		<span class="fr">Référence</span>
		<span class="it">Riferimento</span>
                <span class="ja">リファレンス</span>
		<span class="zh-CN">参考</span>
		<span class="zh-TW">參考資料</span>
	<?cs /if ?>
	</a></li>
	<li><a href="http://android-developers.blogspot.com" onClick="return requestAppendHL(this.href)">
	<?cs if:!sdk.redirect ?>
		<span class="en">Blog</span>
		<span class="de"></span>
		<span class="es"></span>
		<span class="fr"></span>
		<span class="it"></span>
                <span class="ja">ブログ</span>
		<span class="zh-CN">博客</span>
		<span class="zh-TW">網誌</span>
	<?cs /if ?>
	</a></li>
	<li id="videos-link"><a href="<?cs var:toroot ?>videos/index.html" onClick="return loadLast('videos')">
	<?cs if:!sdk.redirect ?>
		<span class="en">Videos</span>
		<span class="de"></span>
		<span class="es"></span>
		<span class="fr"></span>
		<span class="it"></span>
                <span class="ja">ビデオ</span>
		<span class="zh-CN"></span>
		<span class="zh-TW"></span>
	<?cs /if ?>
	</a></li>
	<li id="community-link"><a href="<?cs var:toroot ?>community/index.html">
	<?cs if:!sdk.redirect ?>
		<span class="en">Community</span>
		<span class="de"></span>
		<span class="es">Comunidad</span>
		<span class="fr">Communauté</span>
		<span class="it"></span>
                <span class="ja">コミュニティ</span>
		<span class="zh-CN">社区</span>
		<span class="zh-TW">社群</span>
	<?cs /if ?>
	</a></li>
     
</ul>
