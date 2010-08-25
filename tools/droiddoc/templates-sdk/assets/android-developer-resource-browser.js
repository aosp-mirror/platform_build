(function() { // anonymize

var allTags = {};
var loadedResults = [];

/**
 * Initialization code run upon the DOM being ready.
 */
$(document).ready(function() {
  // Parse page query parameters.
  var params = parseParams(document.location.search);
  params.tag = params.tag ? makeArray(params.tag) : null;

  // Load tag and resource dataset.
  loadTags();
  loadResources();

  showResults(params);

  // Watch for keypresses in the keyword filter textbox, and update
  // search results to reflect the keyword filter.
  $('#resource-browser-keyword-filter').keyup(function() {
    // Filter results on screen by keyword.
    var keywords = $(this).val().split(/\s+/g);
    for (var i = 0; i < loadedResults.length; i++) {
      var hide = false;
      for (var j = 0; j < keywords.length; j++) {
        if (!resultMatchesKeyword(loadedResults[i].result, keywords[j])) {
          hide = true;
          break;
        }
      }

      loadedResults[i].node[hide ? 'hide' : 'show']();
    }
  });
});

/**
 * Returns whether or not the given search result contains the given keyword.
 */
function resultMatchesKeyword(result, keyword) {
  keyword = keyword.toLowerCase();
  if (result.title &&
      result.title.en.toLowerCase().indexOf(keyword) >= 0)
    return true;
  else if (result.description &&
           result.description.en.toLowerCase().indexOf(keyword) >= 0)
    return true;
  else if (result.topicsHtml &&
           result.topicsHtml.replace(/\<.*?\>/g,'').toLowerCase().indexOf(keyword) >= 0)
    return true;
  return false;
}

/**
 * Populates the allTags array with tag data from the ANDROID_TAGS
 * variable in the resource data JS file.
 */
function loadTags() {
  for (var tagClass in ANDROID_TAGS) {
    for (var tag in ANDROID_TAGS[tagClass]) {
      allTags[tag] = {
        displayTag: ANDROID_TAGS[tagClass][tag],
        tagClass: tagClass
      };
    }
  }
}

/**
 * Massage the ANDROID_RESOURCES resource list in the resource data JS file.
 */
function loadResources() {
  for (var i = 0; i < ANDROID_RESOURCES.length; i++) {
    var resource = ANDROID_RESOURCES[i];

    // Convert the tags array to a tags hash for easier querying.
    resource.tagsHash = {};
    for (var j = 0; j < resource.tags.length; j++)
      resource.tagsHash[resource.tags[j]] = true;

    // Determine the type and topics of the resource by inspecting its tags.
    resource.topics = [];
    for (tag in resource.tagsHash)
      if (tag in allTags) {
        if (allTags[tag].tagClass == 'type') {
          resource.type = tag;
        } else if (allTags[tag].tagClass == 'topic') {
          resource.topics.push(tag);
        }
      }

    // Add a humanized topics list string.
    resource.topicsHtml = humanizeList(resource.topics, function(item) {
      return '<strong>' + allTags[item].displayTag + '</strong>';
    });
  }
}

/**
 * Loads resources for the given query parameters.
 */
function showResults(params) {
  loadedResults = [];
  $('#resource-browser-search-params').empty();
  $('#resource-browser-results').empty();

  var i, j;
  var searchTags = [];
  if (params.tag) {
    for (i = 0; i < params.tag.length; i++) {
      var tag = params.tag[i];
      if (tag.toLowerCase() in allTags) {
        searchTags.push(tag.toLowerCase());
      }
    }
  }

  if (searchTags.length) {
    // Show query params.
    var taggedWithHtml = ['Showing technical resources tagged with '];
    taggedWithHtml.push(humanizeList(searchTags, function(item) {
      return '<strong>' + allTags[item].displayTag + '</strong>';
    }));
    $('#resource-browser-search-params').html(taggedWithHtml.join('') + ':');
  } else {
    $('#resource-browser-search-params').html('Showing all technical resources:');
  }

  var results = [];

  // Create the list of resources to show.
  for (i = 0; i < ANDROID_RESOURCES.length; i++) {
    var resource = ANDROID_RESOURCES[i];
    var skip = false;

    if (searchTags.length) {
      for (j = 0; j < searchTags.length; j++)
        if (!(searchTags[j] in resource.tagsHash)) {
          skip = true;
          break;
        }

      if (skip)
        continue;

      results.push(resource);
      continue;
    }

    results.push(resource);
  }

  // Format and show the list of resource results.
  if (results.length) {
    $('#resource-browser-results .no-results').hide();
    for (i = 0; i < results.length; i++) {
      var result = results[i];
      var resultJqNode = $(tmpl('tmpl_resource_browser_result', result));
      for (tag in result.tagsHash)
        resultJqNode.addClass('tagged-' + tag);
      $('#resource-browser-results').append(resultJqNode);

      loadedResults.push({ node: resultJqNode, result: result });
    }
  } else {
    $('#resource-browser-results .no-results').show();
  }
}

/**
 * Formats the given array into a human readable, English string, ala
 * 'a, b and c', with an optional item formatter/wrapper function.
 */
function humanizeList(arr, itemFormatter) {
  itemFormatter = itemFormatter || function(o){ return o; };
  arr = arr || [];

  var out = [];
  for (var i = 0; i < arr.length; i++) {
    out.push(itemFormatter(arr[i]) +
        ((i < arr.length - 2) ? ', ' : '') +
        ((i == arr.length - 2) ? ' and ' : ''));
  }

  return out.join('');
}

/**
 * Parses a parameter string, i.e. foo=1&bar=2 into
 * a dictionary object.
 */
function parseParams(paramStr) {
  var params = {};
  paramStr = paramStr.replace(/^[?#]/, '');

  var pairs = paramStr.split('&');
  for (var i = 0; i < pairs.length; i++) {
    var p = pairs[i].split('=');
    var key = p[0] ? decodeURIComponent(p[0]) : p[0];
    var val = p[1] ? decodeURIComponent(p[1]) : p[1];
    if (val === '0')
      val = 0;
    if (val === '1')
      val = 1;

    if (key in params) {
      // Handle array values.
      params[key] = makeArray(params[key]);
      params[key].push(val);
    } else {
      params[key] = val;
    }
  }

  return params;
}

/**
 * Returns the argument as a single-element array, or the argument itself
 * if it's already an array.
 */
function makeArray(o) {
  if (!o)
    return [];

  if (typeof o === 'object' && 'splice' in o) {
    return o;
  } else {
    return [o];
  }
}

})();
