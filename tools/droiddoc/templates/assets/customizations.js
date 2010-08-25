function showApiWarning(thing, selectedLevel, minLevel) {
  if (selectedLevel < minLevel) {
	  $("#naMessage").show().html("<div><p><strong>This " + thing + " is not available with API Level " + selectedLevel + ".</strong></p>"
	      + "<p>To use this " + thing + ", your application must specify API Level " + minLevel + " or higher in its manifest "
	      + "and be compiled against a version of the Android library that supports an equal or higher API Level. To reveal this "
	      + "document, change the value of the API Level filter above.</p>"
	      + "<p><a href='" +toRoot+ "guide/appendix/api-levels.html'>What is the API Level?</a></p></div>");
  } else {
    $("#naMessage").hide();
  }
}
