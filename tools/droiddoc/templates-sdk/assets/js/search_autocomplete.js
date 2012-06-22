/**
 * jQuery history event v0.1
 * Copyright (c) 2008 Tom Rodenberg <tarodenberg gmail com>
 * Licensed under the GPL (http://www.gnu.org/licenses/gpl.html) license.
 */
(function($) {
    var currentHash, previousNav, timer, hashTrim = /^.*#/;

    var msie = {
        iframe: null,
        getDoc: function() {
            return msie.iframe.contentWindow.document;
        },
        getHash: function() {
            return msie.getDoc().location.hash;
        },
        setHash: function(hash) {
            var d = msie.getDoc();
            d.open();
            d.close();
            d.location.hash = hash;
        }
    };

    var historycheck = function() {
        var hash = msie.iframe ? msie.getHash() : location.hash;
        if (hash != currentHash) {
            currentHash = hash;
            if (msie.iframe) {
                location.hash = currentHash;
            }
            var current = $.history.getCurrent();
            $.event.trigger('history', [current, previousNav]);
            previousNav = current;
        }
    };

    $.history = {
        add: function(hash) {
            hash = '#' + hash.replace(hashTrim, '');
            if (currentHash != hash) {
                var previous = $.history.getCurrent();
                location.hash = currentHash = hash;
                if (msie.iframe) {
                    msie.setHash(currentHash);
                }
                $.event.trigger('historyadd', [$.history.getCurrent(), previous]);
            }
            if (!timer) {
                timer = setInterval(historycheck, 100);
            }
        },
        getCurrent: function() {
            if (currentHash) {
              return currentHash.replace(hashTrim, '');
            } else { 
              return ""; 
            }
        }
    };

    $.fn.history = function(fn) {
        $(this).bind('history', fn);
    };

    $.fn.historyadd = function(fn) {
        $(this).bind('historyadd', fn);
    };

    $(function() {
        currentHash = location.hash;
        if ($.browser.msie) {
            msie.iframe = $('<iframe style="display:none"src="javascript:false;"></iframe>')
                            .prependTo('body')[0];
            msie.setHash(currentHash);
            currentHash = msie.getHash();
        }
    });
})(jQuery);












var gSelectedIndex = -1;
var gSelectedID = -1;
var gMatches = new Array();
var gLastText = "";
var ROW_COUNT = 20;
var gInitialized = false;

function set_item_selected($li, selected)
{
    if (selected) {
        $li.attr('class','jd-autocomplete jd-selected');
    } else {
        $li.attr('class','jd-autocomplete');
    }
}

function set_item_values(toroot, $li, match)
{
    var $link = $('a',$li);
    $link.html(match.__hilabel || match.label);
    $link.attr('href',toroot + match.link);
}

function sync_selection_table(toroot)
{
    var $list = $("#search_filtered");
    var $li; //list item jquery object
    var i; //list item iterator
    gSelectedID = -1;
    
    //initialize the table; draw it for the first time (but not visible).
    if (!gInitialized) {
        for (i=0; i<ROW_COUNT; i++) {
            var $li = $("<li class='jd-autocomplete'></li>");
            $list.append($li);
            
            $li.mousedown(function() {
                window.location = this.firstChild.getAttribute("href");
            });
            $li.mouseover(function() {
                $('#search_filtered li').removeClass('jd-selected');
                $(this).addClass('jd-selected');
                gSelectedIndex = $('#search_filtered li').index(this);
            });
            $li.append('<a></a>');
        }
        gInitialized = true;
    }
  
    //if we have results, make the table visible and initialize result info
    if (gMatches.length > 0) {
        $('#search_filtered_div').removeClass('no-display');
        var N = gMatches.length < ROW_COUNT ? gMatches.length : ROW_COUNT;
        for (i=0; i<N; i++) {
            $li = $('#search_filtered li:nth-child('+(i+1)+')');
            $li.attr('class','show-item');
            set_item_values(toroot, $li, gMatches[i]);
            set_item_selected($li, i == gSelectedIndex);
            if (i == gSelectedIndex) {
                gSelectedID = gMatches[i].id;
            }
        }
        //start hiding rows that are no longer matches
        for (; i<ROW_COUNT; i++) {
            $li = $('#search_filtered li:nth-child('+(i+1)+')');
            $li.attr('class','no-display');
        }
        //if there are more results we're not showing, so say so.
/*      if (gMatches.length > ROW_COUNT) {
            li = list.rows[ROW_COUNT];
            li.className = "show-item";
            c1 = li.cells[0];
            c1.innerHTML = "plus " + (gMatches.length-ROW_COUNT) + " more"; 
        } else {
            list.rows[ROW_COUNT].className = "hide-item";
        }*/
    //if we have no results, hide the table
    } else {
        $('#search_filtered_div').addClass('no-display');
    }
}

function search_changed(e, kd, toroot)
{
    var search = document.getElementById("search_autocomplete");
    var text = search.value.replace(/(^ +)|( +$)/g, '');
    
    // show/hide the close button
    if (text != '') {
        $(".search .close").removeClass("hide");
    } else {
        $(".search .close").addClass("hide");
    }

    // 13 = enter
    if (e.keyCode == 13) {
        $('#search_filtered_div').addClass('no-display');
        if (!$('#search_filtered_div').hasClass('no-display') || (gSelectedIndex < 0)) {
            return true;
        } else if (kd && gSelectedIndex >= 0) {
            window.location = toroot + gMatches[gSelectedIndex].link;
            return false;
        }
    }
    // 38 -- arrow up
    else if (kd && (e.keyCode == 38)) {
        if (gSelectedIndex >= 0) {
            $('#search_filtered li').removeClass('jd-selected');
            gSelectedIndex--;
            $('#search_filtered li:nth-child('+(gSelectedIndex+1)+')').addClass('jd-selected');
        }
        return false;
    }
    // 40 -- arrow down
    else if (kd && (e.keyCode == 40)) {
        if (gSelectedIndex < gMatches.length-1
                        && gSelectedIndex < ROW_COUNT-1) {
            $('#search_filtered li').removeClass('jd-selected');
            gSelectedIndex++;
            $('#search_filtered li:nth-child('+(gSelectedIndex+1)+')').addClass('jd-selected');
        }
        return false;
    }
    else if (!kd && (e.keyCode != 40) && (e.keyCode != 38)) {
        gMatches = new Array();
        matchedCount = 0;
        gSelectedIndex = -1;
        for (var i=0; i<DATA.length; i++) {
            var s = DATA[i];
            if (text.length != 0 &&
                  s.label.toLowerCase().indexOf(text.toLowerCase()) != -1) {
                gMatches[matchedCount] = s;
                matchedCount++;
            }
        }
        rank_autocomplete_results(text);
        for (var i=0; i<gMatches.length; i++) {
            var s = gMatches[i];
            if (gSelectedID == s.id) {
                gSelectedIndex = i;
            }
        }
        highlight_autocomplete_result_labels(text);
        sync_selection_table(toroot);
        return true; // allow the event to bubble up to the search api
    }
}

function rank_autocomplete_results(query) {
    query = query || '';
    if (!gMatches || !gMatches.length)
      return;

    // helper function that gets the last occurence index of the given regex
    // in the given string, or -1 if not found
    var _lastSearch = function(s, re) {
      if (s == '')
        return -1;
      var l = -1;
      var tmp;
      while ((tmp = s.search(re)) >= 0) {
        if (l < 0) l = 0;
        l += tmp;
        s = s.substr(tmp + 1);
      }
      return l;
    };

    // helper function that counts the occurrences of a given character in
    // a given string
    var _countChar = function(s, c) {
      var n = 0;
      for (var i=0; i<s.length; i++)
        if (s.charAt(i) == c) ++n;
      return n;
    };

    var queryLower = query.toLowerCase();
    var queryAlnum = (queryLower.match(/\w+/) || [''])[0];
    var partPrefixAlnumRE = new RegExp('\\b' + queryAlnum);
    var partExactAlnumRE = new RegExp('\\b' + queryAlnum + '\\b');

    var _resultScoreFn = function(result) {
        // scores are calculated based on exact and prefix matches,
        // and then number of path separators (dots) from the last
        // match (i.e. favoring classes and deep package names)
        var score = 1.0;
        var labelLower = result.label.toLowerCase();
        var t;
        t = _lastSearch(labelLower, partExactAlnumRE);
        if (t >= 0) {
            // exact part match
            var partsAfter = _countChar(labelLower.substr(t + 1), '.');
            score *= 200 / (partsAfter + 1);
        } else {
            t = _lastSearch(labelLower, partPrefixAlnumRE);
            if (t >= 0) {
                // part prefix match
                var partsAfter = _countChar(labelLower.substr(t + 1), '.');
                score *= 20 / (partsAfter + 1);
            }
        }

        return score;
    };

    for (var i=0; i<gMatches.length; i++) {
        gMatches[i].__resultScore = _resultScoreFn(gMatches[i]);
    }

    gMatches.sort(function(a,b){
        var n = b.__resultScore - a.__resultScore;
        if (n == 0) // lexicographical sort if scores are the same
            n = (a.label < b.label) ? -1 : 1;
        return n;
    });
}

function highlight_autocomplete_result_labels(query) {
    query = query || '';
    if (!gMatches || !gMatches.length)
      return;

    var queryLower = query.toLowerCase();
    var queryAlnumDot = (queryLower.match(/[\w\.]+/) || [''])[0];
    var queryRE = new RegExp(
        '(' + queryAlnumDot.replace(/\./g, '\\.') + ')', 'ig');
    for (var i=0; i<gMatches.length; i++) {
        gMatches[i].__hilabel = gMatches[i].label.replace(
            queryRE, '<b>$1</b>');
    }
}

function search_focus_changed(obj, focused)
{
    if (!focused) {     
        if(obj.value == ""){
          $(".search .close").addClass("hide");
        }
        document.getElementById("search_filtered_div").className = "no-display";
    }
}

function submit_search() {
  var query = document.getElementById('search_autocomplete').value;
  location.hash = 'q=' + query;
  $.history.add('q=' + query);
  loadSearchResults();
  $("#searchResults").slideDown();
  return false;
}


function hideResults() {
  $("#searchResults").slideUp();
  $(".search .close").addClass("hide");
  location.hash = '';
  drawOptions.setInput(document.getElementById("searchResults"));
  
  $("#search_autocomplete").blur();
  return false;
}












/************ SEARCH ENGINE ***************/

            
      google.load('search', '1');

      function loadSearchResults() {
        if (location.hash.indexOf("q=") == -1) {
          // if there's no query in the url, don't search and make sure results are hidden
          $('#searchResults').hide();
          return;
        }
        
        var $results = $("#searchResults");
        if ($results.is(":hidden")) {
          $results.slideDown();
        }
        
        document.getElementById("search_autocomplete").style.color = "#000";

        // create search control
        searchControl = new google.search.SearchControl();

        // use our existing search form and use tabs when multiple searchers are used
        drawOptions = new google.search.DrawOptions();
        drawOptions.setDrawMode(google.search.SearchControl.DRAW_MODE_TABBED);
        drawOptions.setInput(document.getElementById("search_autocomplete"));

        // configure search result options
        searchOptions = new google.search.SearcherOptions();
        searchOptions.setExpandMode(GSearchControl.EXPAND_MODE_OPEN);

        // configure each of the searchers, for each tab
        devSiteSearcher = new google.search.WebSearch();
        devSiteSearcher.setUserDefinedLabel("All");
        devSiteSearcher.setSiteRestriction("001482626316274216503:zu90b7s047u");

        designSearcher = new google.search.WebSearch();
        designSearcher.setUserDefinedLabel("Design");
        designSearcher.setSiteRestriction("http://developer.android.com/design/");

        trainingSearcher = new google.search.WebSearch();
        trainingSearcher.setUserDefinedLabel("Training");
        trainingSearcher.setSiteRestriction("http://developer.android.com/training/");

        guidesSearcher = new google.search.WebSearch();
        guidesSearcher.setUserDefinedLabel("Guides");
        guidesSearcher.setSiteRestriction("http://developer.android.com/guide/");

        referenceSearcher = new google.search.WebSearch();
        referenceSearcher.setUserDefinedLabel("Reference");
        referenceSearcher.setSiteRestriction("http://developer.android.com/reference/");

        blogSearcher = new google.search.WebSearch();
        blogSearcher.setUserDefinedLabel("Blog");
        blogSearcher.setSiteRestriction("http://android-developers.blogspot.com");
 
        // add each searcher to the search control
        searchControl.addSearcher(devSiteSearcher, searchOptions);
        searchControl.addSearcher(designSearcher, searchOptions);
        searchControl.addSearcher(trainingSearcher, searchOptions);
        searchControl.addSearcher(guidesSearcher, searchOptions);
        searchControl.addSearcher(referenceSearcher, searchOptions);
        searchControl.addSearcher(blogSearcher, searchOptions);

        // configure result options
        searchControl.setResultSetSize(google.search.Search.LARGE_RESULTSET);
        searchControl.setLinkTarget(google.search.Search.LINK_TARGET_SELF);
        searchControl.setTimeoutInterval(google.search.SearchControl.TIMEOUT_LONG);
        searchControl.setNoResultsString(google.search.SearchControl.NO_RESULTS_DEFAULT_STRING);

        // upon ajax search, refresh the url and search title
        searchControl.setSearchStartingCallback(this, function(control, searcher, query) {
          updateResultTitle(query);
          var query = document.getElementById('search_autocomplete').value;
          location.hash = 'q=' + query;
          $.history.add('q=' + query);
        });

        // draw the search results box
        searchControl.draw(document.getElementById("leftSearchControl"), drawOptions);

        // get query and execute the search
        searchControl.execute(decodeURI(getQuery(location.hash)));

        document.getElementById("search_autocomplete").focus();
        addTabListeners();
      }
      // End of loadSearchResults


      google.setOnLoadCallback(loadSearchResults, true);

      // when an event on the browser history occurs (back, forward, load) perform a search
      $(window).history(function(e, hash) {
        var query = decodeURI(getQuery(hash));
        if (query == "undefined") {
          hideResults(); 
          return; 
        }
        searchControl.execute(query);

        updateResultTitle(query);
      });
      
      function updateResultTitle(query) {
        $("#searchTitle").html("Results for <em>" + escapeHTML(query) + "</em>");
      }

      // forcefully regain key-up event control (previously jacked by search api)
      $("#search_autocomplete").keyup(function(event) {
        return search_changed(event, false, '/');
      });

      // add event listeners to each tab so we can track the browser history
      function addTabListeners() {
        var tabHeaders = $(".gsc-tabHeader");
        for (var i = 0; i < tabHeaders.length; i++) {
          $(tabHeaders[i]).attr("id",i).click(function() {
          /*
            // make a copy of the page numbers for the search left pane
            setTimeout(function() {
              // remove any residual page numbers
              $('#searchResults .gsc-tabsArea .gsc-cursor-box.gs-bidi-start-align').remove();
              // move the page numbers to the left position; make a clone, 
              // because the element is drawn to the DOM only once
              // and because we're going to remove it (previous line), 
              // we need it to be available to move again as the user navigates 
              $('#searchResults .gsc-webResult .gsc-cursor-box.gs-bidi-start-align:visible')
                              .clone().appendTo('#searchResults .gsc-tabsArea');
              }, 200);
           */
          });
        }
        setTimeout(function(){$(tabHeaders[0]).click()},200);
      }


      function getQuery(hash) {
        var queryParts = hash.split('=');
        return queryParts[1];
      }

      /* returns the given string with all HTML brackets converted to entities
         TODO: move this to the site's JS library */
      function escapeHTML(string) {
        return string.replace(/</g,"&lt;")
                     .replace(/>/g,"&gt;");
      }


