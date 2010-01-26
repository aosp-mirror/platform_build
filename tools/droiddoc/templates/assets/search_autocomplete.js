var gSelectedIndex = -1;
var gSelectedID = -1;
var gMatches = new Array();
var gLastText = "";
var ROW_COUNT = 30;
var gInitialized = false;
var DEFAULT_TEXT = "search developer docs";

function set_row_selected(row, selected)
{
    var c1 = row.cells[0];
  //  var c2 = row.cells[1];
    if (selected) {
        c1.className = "jd-autocomplete jd-selected";
  //      c2.className = "jd-autocomplete jd-selected jd-linktype";
    } else {
        c1.className = "jd-autocomplete";
  //      c2.className = "jd-autocomplete jd-linktype";
    }
}

function set_row_values(toroot, row, match)
{
    var link = row.cells[0].childNodes[0];
    link.innerHTML = match.label;
    link.href = toroot + match.link
  //  row.cells[1].innerHTML = match.type;
}

function sync_selection_table(toroot)
{
    var filtered = document.getElementById("search_filtered");
    var r; //TR DOM object
    var i; //TR iterator
    gSelectedID = -1;

    filtered.onmouseover = function() { 
        if(gSelectedIndex >= 0) {
          set_row_selected(this.rows[gSelectedIndex], false);
          gSelectedIndex = -1;
        }
    }

    //initialize the table; draw it for the first time (but not visible).
    if (!gInitialized) {
        for (i=0; i<ROW_COUNT; i++) {
            var r = filtered.insertRow(-1);
            var c1 = r.insertCell(-1);
        //    var c2 = r.insertCell(-1);
            c1.className = "jd-autocomplete";
         //   c2.className = "jd-autocomplete jd-linktype";
            var link = document.createElement("a");
            c1.onmousedown = function() {
                window.location = this.firstChild.getAttribute("href");
            }
            c1.onmouseover = function() {
                this.className = this.className + " jd-selected";
            }
            c1.onmouseout = function() {
                this.className = "jd-autocomplete";
            }
            c1.appendChild(link);
        }
  /*      var r = filtered.insertRow(-1);
        var c1 = r.insertCell(-1);
        c1.className = "jd-autocomplete jd-linktype";
        c1.colSpan = 2; */
        gInitialized = true;
    }

    //if we have results, make the table visible and initialize result info
    if (gMatches.length > 0) {
        document.getElementById("search_filtered_div").className = "showing";
        var N = gMatches.length < ROW_COUNT ? gMatches.length : ROW_COUNT;
        for (i=0; i<N; i++) {
            r = filtered.rows[i];
            r.className = "show-row";
            set_row_values(toroot, r, gMatches[i]);
            set_row_selected(r, i == gSelectedIndex);
            if (i == gSelectedIndex) {
                gSelectedID = gMatches[i].id;
            }
        }
        //start hiding rows that are no longer matches
        for (; i<ROW_COUNT; i++) {
            r = filtered.rows[i];
            r.className = "no-display";
        }
        //if there are more results we're not showing, so say so.
/*      if (gMatches.length > ROW_COUNT) {
            r = filtered.rows[ROW_COUNT];
            r.className = "show-row";
            c1 = r.cells[0];
            c1.innerHTML = "plus " + (gMatches.length-ROW_COUNT) + " more"; 
        } else {
            filtered.rows[ROW_COUNT].className = "hide-row";
        }*/
    //if we have no results, hide the table
    } else {
        document.getElementById("search_filtered_div").className = "no-display";
    }
}

function search_changed(e, kd, toroot)
{
    var search = document.getElementById("search_autocomplete");
    var text = search.value;

    // 13 = enter
    if (e.keyCode == 13) {
        document.getElementById("search_filtered_div").className = "no-display";
        if (kd && gSelectedIndex >= 0) {
            window.location = toroot + gMatches[gSelectedIndex].link;
            return false;
        } else if (gSelectedIndex < 0) {
            return true;
        }
    }
    // 38 -- arrow up
    else if (kd && (e.keyCode == 38)) {
        if (gSelectedIndex >= 0) {
            gSelectedIndex--;
        }
        sync_selection_table(toroot);
        return false;
    }
    // 40 -- arrow down
    else if (kd && (e.keyCode == 40)) {
        if (gSelectedIndex < gMatches.length-1
                        && gSelectedIndex < ROW_COUNT-1) {
            gSelectedIndex++;
        }
        sync_selection_table(toroot);
        return false;
    }
    else if (!kd) {
        gMatches = new Array();
        matchedCount = 0;
        gSelectedIndex = -1;
        for (i=0; i<DATA.length; i++) {
            var s = DATA[i];
            if (text.length != 0 && s.label.indexOf(text) != -1) {
                gMatches[matchedCount] = s;
                if (gSelectedID == s.id) {
                    gSelectedIndex = matchedCount;
                }
                matchedCount++;
            }
        }
        sync_selection_table(toroot);
        return true; // allow the event to bubble up to the search api
    }
}

function search_focus_changed(obj, focused)
{
    if (focused) {
        if(obj.value == DEFAULT_TEXT){
            obj.value = "";
            obj.style.color="#000000";
        }
    } else {
        if(obj.value == ""){
          obj.value = DEFAULT_TEXT;
          obj.style.color="#aaaaaa";
        }
        document.getElementById("search_filtered_div").className = "no-display";
    }
}

function submit_search() {
  var query = document.getElementById('search_autocomplete').value;
  document.location = toRoot + 'search.html#q=' + query + '&t=0';
  return false;
}
