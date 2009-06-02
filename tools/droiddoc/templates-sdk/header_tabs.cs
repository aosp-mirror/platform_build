<ul id="header-tabs" class="<?cs 
	if:reference ?>reference<?cs
	elif:guide ?>guide<?cs
	elif:sdk ?>sdk<?cs
	elif:home ?>home<?cs
	elif:community ?>community<?cs
	elif:publish ?>publish<?cs
	elif:about ?>about<?cs /if ?>">
         
	<li id="home-link"><a href="<?cs var:toroot ?><?cs if:android.whichdoc != "online" ?>offline.html<?cs else ?>index.html<?cs /if ?>">
		<span class="en">Home</span>
    <span class="ja"></span>
	</a></li>
	<li id="sdk-link"><a href="<?cs var:toroot ?>sdk/<?cs var:sdk.current ?>/index.html">
		<span class="en">SDK</span>
    <span class="ja"></span>
	</a></li>
	<li id="guide-link"><a href="<?cs var:toroot ?>guide/index.html" onClick="return loadLast('guide')">
		<span class="en">Dev Guide</span>
    <span class="ja"></span>
	</a></li>
	<li id="reference-link"><a href="<?cs var:toroot ?>reference/packages.html" onClick="return loadLast('reference')">
		<span class="en">Reference</span>
    <span class="ja"></span>
	</a></li>
	<li><a href="http://android-developers.blogspot.com">
		<span class="en">Blog</span>
    <span class="ja"></span>
	</a></li>
	<li id="community-link"><a href="<?cs var:toroot ?>community/index.html">
		<span class="en">Community</span>
    <span class="ja"></span>
	</a></li>
     
</ul>