# Lint as: python3
# Copyright (C) 2019 The Android Open Source Project
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""Emit warning messages to html or csv files."""

# Many functions in this module have too many arguments to be refactored.
# pylint:disable=too-many-arguments,missing-function-docstring

# To emit html page of warning messages:
#   flags: --byproject, --url, --separator
# Old stuff for static html components:
#   html_script_style:  static html scripts and styles
#   htmlbig:
#   dump_stats, dump_html_prologue, dump_html_epilogue:
#   emit_buttons:
#   dump_fixed
#   sort_warnings:
#   emit_stats_by_project:
#   all_patterns,
#   findproject, classify_warning
#   dump_html
#
# New dynamic HTML page's static JavaScript data:
#   Some data are copied from Python to JavaScript, to generate HTML elements.
#   FlagPlatform           flags.platform
#   FlagURL                flags.url, used by 'android'
#   FlagSeparator          flags.separator, used by 'android'
#   SeverityColors:        list of colors for all severity levels
#   SeverityHeaders:       list of headers for all severity levels
#   SeverityColumnHeaders: list of column_headers for all severity levels
#   ProjectNames:          project_names, or project_list[*][0]
#   WarnPatternsSeverity:     warn_patterns[*]['severity']
#   WarnPatternsDescription:  warn_patterns[*]['description']
#   WarningMessages:          warning_messages
#   Warnings:                 warning_records
#   StatsHeader:           warning count table header row
#   StatsRows:             array of warning count table rows
#
# New dynamic HTML page's dynamic JavaScript data:
#
# New dynamic HTML related function to emit data:
#   escape_string, strip_escape_string, emit_warning_arrays
#   emit_js_data():

from __future__ import print_function
import csv
import html
import sys

# pylint:disable=relative-beyond-top-level
from .severity import Severity


HTML_HEAD_SCRIPTS = """\
  <script type="text/javascript">
  function expand(id) {
    var e = document.getElementById(id);
    var f = document.getElementById(id + "_mark");
    if (e.style.display == 'block') {
       e.style.display = 'none';
       f.innerHTML = '&#x2295';
    }
    else {
       e.style.display = 'block';
       f.innerHTML = '&#x2296';
    }
  };
  function expandCollapse(show) {
    for (var id = 1; ; id++) {
      var e = document.getElementById(id + "");
      var f = document.getElementById(id + "_mark");
      if (!e || !f) break;
      e.style.display = (show ? 'block' : 'none');
      f.innerHTML = (show ? '&#x2296' : '&#x2295');
    }
  };
  </script>
  <style type="text/css">
  th,td{border-collapse:collapse; border:1px solid black;}
  .button{color:blue;font-size:110%;font-weight:bolder;}
  .bt{color:black;background-color:transparent;border:none;outline:none;
      font-size:140%;font-weight:bolder;}
  .c0{background-color:#e0e0e0;}
  .c1{background-color:#d0d0d0;}
  .t1{border-collapse:collapse; width:100%; border:1px solid black;}
  </style>
  <script src="https://www.gstatic.com/charts/loader.js"></script>
"""


def make_writer(output_stream):

  def writer(text):
    return output_stream.write(text + '\n')

  return writer


def html_big(param):
  return '<font size="+2">' + param + '</font>'


def dump_html_prologue(title, writer, warn_patterns, project_names):
  writer('<html>\n<head>')
  writer('<title>' + title + '</title>')
  writer(HTML_HEAD_SCRIPTS)
  emit_stats_by_project(writer, warn_patterns, project_names)
  writer('</head>\n<body>')
  writer(html_big(title))
  writer('<p>')


def dump_html_epilogue(writer):
  writer('</body>\n</head>\n</html>')


def sort_warnings(warn_patterns):
  for i in warn_patterns:
    i['members'] = sorted(set(i['members']))


def create_warnings(warn_patterns, project_names):
  """Creates warnings s.t.

  warnings[p][s] is as specified in above docs.

  Args:
    warn_patterns: list of warning patterns for specified platform
    project_names: list of project names

  Returns:
    2D warnings array where warnings[p][s] is # of warnings in project name p of
    severity level s
  """
  warnings = {p: {s.value: 0 for s in Severity.levels} for p in project_names}
  for pattern in warn_patterns:
    value = pattern['severity'].value
    for project in pattern['projects']:
      warnings[project][value] += pattern['projects'][project]
  return warnings


def get_total_by_project(warnings, project_names):
  """Returns dict, project as key and # warnings for that project as value."""
  return {
      p: sum(warnings[p][s.value] for s in Severity.levels)
      for p in project_names
  }


def get_total_by_severity(warnings, project_names):
  """Returns dict, severity as key and # warnings of that severity as value."""
  return {
      s.value: sum(warnings[p][s.value] for p in project_names)
      for s in Severity.levels
  }


def emit_table_header(total_by_severity):
  """Returns list of HTML-formatted content for severity stats."""

  stats_header = ['Project']
  for severity in Severity.levels:
    if total_by_severity[severity.value]:
      stats_header.append(
          '<span style=\'background-color:{}\'>{}</span>'.format(
              severity.color, severity.column_header))
  stats_header.append('TOTAL')
  return stats_header


def emit_row_counts_per_project(warnings, total_by_project, total_by_severity,
                                project_names):
  """Returns total project warnings and row of stats for each project.

  Args:
    warnings: output of create_warnings(warn_patterns, project_names)
    total_by_project: output of get_total_by_project(project_names)
    total_by_severity: output of get_total_by_severity(project_names)
    project_names: list of project names

  Returns:
    total_all_projects, the total number of warnings over all projects
    stats_rows, a 2d list where each row is [Project Name, <severity counts>,
    total # warnings for this project]
  """

  total_all_projects = 0
  stats_rows = []
  for p_name in project_names:
    if total_by_project[p_name]:
      one_row = [p_name]
      for severity in Severity.levels:
        if total_by_severity[severity.value]:
          one_row.append(warnings[p_name][severity.value])
      one_row.append(total_by_project[p_name])
      stats_rows.append(one_row)
      total_all_projects += total_by_project[p_name]
  return total_all_projects, stats_rows


def emit_row_counts_per_severity(total_by_severity, stats_header, stats_rows,
                                 total_all_projects, writer):
  """Emits stats_header and stats_rows as specified above.

  Args:
    total_by_severity: output of get_total_by_severity()
    stats_header: output of emit_table_header()
    stats_rows: output of emit_row_counts_per_project()
    total_all_projects: output of emit_row_counts_per_project()
    writer: writer returned by make_writer(output_stream)
  """

  total_all_severities = 0
  one_row = ['<b>TOTAL</b>']
  for severity in Severity.levels:
    if total_by_severity[severity.value]:
      one_row.append(total_by_severity[severity.value])
      total_all_severities += total_by_severity[severity.value]
  one_row.append(total_all_projects)
  stats_rows.append(one_row)
  writer('<script>')
  emit_const_string_array('StatsHeader', stats_header, writer)
  emit_const_object_array('StatsRows', stats_rows, writer)
  writer(DRAW_TABLE_JAVASCRIPT)
  writer('</script>')


def emit_stats_by_project(writer, warn_patterns, project_names):
  """Dump a google chart table of warnings per project and severity."""

  warnings = create_warnings(warn_patterns, project_names)
  total_by_project = get_total_by_project(warnings, project_names)
  total_by_severity = get_total_by_severity(warnings, project_names)
  stats_header = emit_table_header(total_by_severity)
  total_all_projects, stats_rows = emit_row_counts_per_project(
      warnings, total_by_project, total_by_severity, project_names)
  emit_row_counts_per_severity(total_by_severity, stats_header, stats_rows,
                               total_all_projects, writer)


def dump_stats(writer, warn_patterns):
  """Dump some stats about total number of warnings and such."""

  known = 0
  skipped = 0
  unknown = 0
  sort_warnings(warn_patterns)
  for i in warn_patterns:
    if i['severity'] == Severity.UNMATCHED:
      unknown += len(i['members'])
    elif i['severity'] == Severity.SKIP:
      skipped += len(i['members'])
    else:
      known += len(i['members'])
  writer('Number of classified warnings: <b>' + str(known) + '</b><br>')
  writer('Number of skipped warnings: <b>' + str(skipped) + '</b><br>')
  writer('Number of unclassified warnings: <b>' + str(unknown) + '</b><br>')
  total = unknown + known + skipped
  extra_msg = ''
  if total < 1000:
    extra_msg = ' (low count may indicate incremental build)'
  writer('Total number of warnings: <b>' + str(total) + '</b>' + extra_msg)


# New base table of warnings, [severity, warn_id, project, warning_message]
# Need buttons to show warnings in different grouping options.
# (1) Current, group by severity, id for each warning pattern
#     sort by severity, warn_id, warning_message
# (2) Current --byproject, group by severity,
#     id for each warning pattern + project name
#     sort by severity, warn_id, project, warning_message
# (3) New, group by project + severity,
#     id for each warning pattern
#     sort by project, severity, warn_id, warning_message
def emit_buttons(writer):
  """Write the button elements in HTML."""
  writer('<button class="button" onclick="expandCollapse(1);">'
         'Expand all warnings</button>\n'
         '<button class="button" onclick="expandCollapse(0);">'
         'Collapse all warnings</button>\n'
         '<button class="button" onclick="groupBySeverity();">'
         'Group warnings by severity</button>\n'
         '<button class="button" onclick="groupByProject();">'
         'Group warnings by project</button><br>')


def all_patterns(category):
  patterns = ''
  for i in category['patterns']:
    patterns += i
    patterns += ' / '
  return patterns


def dump_fixed(writer, warn_patterns):
  """Show which warnings no longer occur."""
  anchor = 'fixed_warnings'
  mark = anchor + '_mark'
  writer('\n<br><p style="background-color:lightblue"><b>'
         '<button id="' + mark + '" '
         'class="bt" onclick="expand(\'' + anchor + '\');">'
         '&#x2295</button> Fixed warnings. '
         'No more occurrences. Please consider turning these into '
         'errors if possible, before they are reintroduced in to the build'
         ':</b></p>')
  writer('<blockquote>')
  fixed_patterns = []
  for i in warn_patterns:
    if not i['members']:
      fixed_patterns.append(i['description'] + ' (' + all_patterns(i) + ')')
  fixed_patterns = sorted(fixed_patterns)
  writer('<div id="' + anchor + '" style="display:none;"><table>')
  cur_row_class = 0
  for text in fixed_patterns:
    cur_row_class = 1 - cur_row_class
    # remove last '\n'
    out_text = text[:-1] if text[-1] == '\n' else text
    writer('<tr><td class="c' + str(cur_row_class) + '">'
           + out_text + '</td></tr>')
  writer('</table></div>')
  writer('</blockquote>')


def write_severity(csvwriter, sev, kind, warn_patterns):
  """Count warnings of given severity and write CSV entries to writer."""
  total = 0
  for pattern in warn_patterns:
    if pattern['severity'] == sev and pattern['members']:
      num_members = len(pattern['members'])
      total += num_members
      warning = kind + ': ' + (pattern['description'] or '?')
      csvwriter.writerow([num_members, '', warning])
      # print number of warnings for each project, ordered by project name
      projects = sorted(pattern['projects'].keys())
      for project in projects:
        csvwriter.writerow([pattern['projects'][project], project, warning])
  csvwriter.writerow([total, '', kind + ' warnings'])
  return total


def dump_csv(csvwriter, warn_patterns):
  """Dump number of warnings in CSV format to writer."""
  sort_warnings(warn_patterns)
  total = 0
  for severity in Severity.levels:
    total += write_severity(
        csvwriter, severity, severity.column_header, warn_patterns)
  csvwriter.writerow([total, '', 'All warnings'])


def dump_csv_with_description(csvwriter, warning_records, warning_messages,
                              warn_patterns, project_names):
  """Outputs all the warning messages by project."""
  csv_output = []
  for record in warning_records:
    project_name = project_names[record[1]]
    pattern = warn_patterns[record[0]]
    severity = pattern['severity'].header
    category = pattern['category']
    description = pattern['description']
    warning = warning_messages[record[2]]
    csv_output.append([project_name, severity,
                       category, description,
                       warning])
  csv_output = sorted(csv_output)
  for output in csv_output:
    csvwriter.writerow(output)


# Return line with escaped backslash and quotation characters.
def escape_string(line):
  return line.replace('\\', '\\\\').replace('"', '\\"')


# Return line without trailing '\n' and escape the quotation characters.
def strip_escape_string(line):
  if not line:
    return line
  line = line[:-1] if line[-1] == '\n' else line
  return escape_string(line)


def emit_warning_array(name, writer, warn_patterns):
  writer('var warning_{} = ['.format(name))
  for pattern in warn_patterns:
    if name == 'severity':
      writer('{},'.format(pattern[name].value))
    else:
      writer('{},'.format(pattern[name]))
  writer('];')


def emit_warning_arrays(writer, warn_patterns):
  emit_warning_array('severity', writer, warn_patterns)
  writer('var warning_description = [')
  for pattern in warn_patterns:
    if pattern['members']:
      writer('"{}",'.format(escape_string(pattern['description'])))
    else:
      writer('"",')  # no such warning
  writer('];')


SCRIPTS_FOR_WARNING_GROUPS = """
  function compareMessages(x1, x2) { // of the same warning type
    return (WarningMessages[x1[2]] <= WarningMessages[x2[2]]) ? -1 : 1;
  }
  function byMessageCount(x1, x2) {
    return x2[2] - x1[2];  // reversed order
  }
  function bySeverityMessageCount(x1, x2) {
    // orer by severity first
    if (x1[1] != x2[1])
      return  x1[1] - x2[1];
    return byMessageCount(x1, x2);
  }
  const ParseLinePattern = /^([^ :]+):(\\d+):(.+)/;
  function addURL(line) { // used by Android
    if (FlagURL == "") return line;
    if (FlagSeparator == "") {
      return line.replace(ParseLinePattern,
        "<a target='_blank' href='" + FlagURL + "/$1'>$1</a>:$2:$3");
    }
    return line.replace(ParseLinePattern,
      "<a target='_blank' href='" + FlagURL + "/$1" + FlagSeparator +
        "$2'>$1:$2</a>:$3");
  }
  function addURLToLine(line, link) { // used by Chrome
      let line_split = line.split(":");
      let path = line_split.slice(0,3).join(":");
      let msg = line_split.slice(3).join(":");
      let html_link = `<a target="_blank" href="${link}">${path}</a>${msg}`;
      return html_link;
  }
  function createArrayOfDictionaries(n) {
    var result = [];
    for (var i=0; i<n; i++) result.push({});
    return result;
  }
  function groupWarningsBySeverity() {
    // groups is an array of dictionaries,
    // each dictionary maps from warning type to array of warning messages.
    var groups = createArrayOfDictionaries(SeverityColors.length);
    for (var i=0; i<Warnings.length; i++) {
      var w = Warnings[i][0];
      var s = WarnPatternsSeverity[w];
      var k = w.toString();
      if (!(k in groups[s]))
        groups[s][k] = [];
      groups[s][k].push(Warnings[i]);
    }
    return groups;
  }
  function groupWarningsByProject() {
    var groups = createArrayOfDictionaries(ProjectNames.length);
    for (var i=0; i<Warnings.length; i++) {
      var w = Warnings[i][0];
      var p = Warnings[i][1];
      var k = w.toString();
      if (!(k in groups[p]))
        groups[p][k] = [];
      groups[p][k].push(Warnings[i]);
    }
    return groups;
  }
  var GlobalAnchor = 0;
  function createWarningSection(header, color, group) {
    var result = "";
    var groupKeys = [];
    var totalMessages = 0;
    for (var k in group) {
       totalMessages += group[k].length;
       groupKeys.push([k, WarnPatternsSeverity[parseInt(k)], group[k].length]);
    }
    groupKeys.sort(bySeverityMessageCount);
    for (var idx=0; idx<groupKeys.length; idx++) {
      var k = groupKeys[idx][0];
      var messages = group[k];
      var w = parseInt(k);
      var wcolor = SeverityColors[WarnPatternsSeverity[w]];
      var description = WarnPatternsDescription[w];
      if (description.length == 0)
          description = "???";
      GlobalAnchor += 1;
      result += "<table class='t1'><tr bgcolor='" + wcolor + "'><td>" +
                "<button class='bt' id='" + GlobalAnchor + "_mark" +
                "' onclick='expand(\\"" + GlobalAnchor + "\\");'>" +
                "&#x2295</button> " +
                description + " (" + messages.length + ")</td></tr></table>";
      result += "<div id='" + GlobalAnchor +
                "' style='display:none;'><table class='t1'>";
      var c = 0;
      messages.sort(compareMessages);
      if (FlagPlatform == "chrome") {
        for (var i=0; i<messages.length; i++) {
          result += "<tr><td class='c" + c + "'>" +
                    addURLToLine(WarningMessages[messages[i][2]], WarningLinks[messages[i][3]]) + "</td></tr>";
          c = 1 - c;
        }
      } else {
        for (var i=0; i<messages.length; i++) {
          result += "<tr><td class='c" + c + "'>" +
                    addURL(WarningMessages[messages[i][2]]) + "</td></tr>";
          c = 1 - c;
        }
      }
      result += "</table></div>";
    }
    if (result.length > 0) {
      return "<br><span style='background-color:" + color + "'><b>" +
             header + ": " + totalMessages +
             "</b></span><blockquote><table class='t1'>" +
             result + "</table></blockquote>";

    }
    return "";  // empty section
  }
  function generateSectionsBySeverity() {
    var result = "";
    var groups = groupWarningsBySeverity();
    for (s=0; s<SeverityColors.length; s++) {
      result += createWarningSection(SeverityHeaders[s], SeverityColors[s],
                                     groups[s]);
    }
    return result;
  }
  function generateSectionsByProject() {
    var result = "";
    var groups = groupWarningsByProject();
    for (i=0; i<groups.length; i++) {
      result += createWarningSection(ProjectNames[i], 'lightgrey', groups[i]);
    }
    return result;
  }
  function groupWarnings(generator) {
    GlobalAnchor = 0;
    var e = document.getElementById("warning_groups");
    e.innerHTML = generator();
  }
  function groupBySeverity() {
    groupWarnings(generateSectionsBySeverity);
  }
  function groupByProject() {
    groupWarnings(generateSectionsByProject);
  }
"""


# Emit a JavaScript const string
def emit_const_string(name, value, writer):
  writer('const ' + name + ' = "' + escape_string(value) + '";')


# Emit a JavaScript const integer array.
def emit_const_int_array(name, array, writer):
  writer('const ' + name + ' = [')
  for item in array:
    writer(str(item) + ',')
  writer('];')


# Emit a JavaScript const string array.
def emit_const_string_array(name, array, writer):
  writer('const ' + name + ' = [')
  for item in array:
    writer('"' + strip_escape_string(item) + '",')
  writer('];')


# Emit a JavaScript const string array for HTML.
def emit_const_html_string_array(name, array, writer):
  writer('const ' + name + ' = [')
  for item in array:
    writer('"' + html.escape(strip_escape_string(item)) + '",')
  writer('];')


# Emit a JavaScript const object array.
def emit_const_object_array(name, array, writer):
  writer('const ' + name + ' = [')
  for item in array:
    writer(str(item) + ',')
  writer('];')


def emit_js_data(writer, flags, warning_messages, warning_links,
                 warning_records, warn_patterns, project_names):
  """Dump dynamic HTML page's static JavaScript data."""
  emit_const_string('FlagPlatform', flags.platform, writer)
  emit_const_string('FlagURL', flags.url, writer)
  emit_const_string('FlagSeparator', flags.separator, writer)
  emit_const_string_array('SeverityColors', [s.color for s in Severity.levels],
                          writer)
  emit_const_string_array('SeverityHeaders',
                          [s.header for s in Severity.levels], writer)
  emit_const_string_array('SeverityColumnHeaders',
                          [s.column_header for s in Severity.levels], writer)
  emit_const_string_array('ProjectNames', project_names, writer)
  # pytype: disable=attribute-error
  emit_const_int_array('WarnPatternsSeverity',
                       [w['severity'].value for w in warn_patterns], writer)
  # pytype: enable=attribute-error
  emit_const_html_string_array('WarnPatternsDescription',
                               [w['description'] for w in warn_patterns],
                               writer)
  emit_const_html_string_array('WarningMessages', warning_messages, writer)
  emit_const_object_array('Warnings', warning_records, writer)
  if flags.platform == 'chrome':
    emit_const_html_string_array('WarningLinks', warning_links, writer)


DRAW_TABLE_JAVASCRIPT = """
google.charts.load('current', {'packages':['table']});
google.charts.setOnLoadCallback(drawTable);
function drawTable() {
  var data = new google.visualization.DataTable();
  data.addColumn('string', StatsHeader[0]);
  for (var i=1; i<StatsHeader.length; i++) {
    data.addColumn('number', StatsHeader[i]);
  }
  data.addRows(StatsRows);
  for (var i=0; i<StatsRows.length; i++) {
    for (var j=0; j<StatsHeader.length; j++) {
      data.setProperty(i, j, 'style', 'border:1px solid black;');
    }
  }
  var table = new google.visualization.Table(
      document.getElementById('stats_table'));
  table.draw(data, {allowHtml: true, alternatingRowStyle: true});
}
"""


def dump_html(flags, output_stream, warning_messages, warning_links,
              warning_records, header_str, warn_patterns, project_names):
  """Dump the flags output to output_stream."""
  writer = make_writer(output_stream)
  dump_html_prologue('Warnings for ' + header_str, writer, warn_patterns,
                     project_names)
  dump_stats(writer, warn_patterns)
  writer('<br><div id="stats_table"></div><br>')
  writer('\n<script>')
  emit_js_data(writer, flags, warning_messages, warning_links, warning_records,
               warn_patterns, project_names)
  writer(SCRIPTS_FOR_WARNING_GROUPS)
  writer('</script>')
  emit_buttons(writer)
  # Warning messages are grouped by severities or project names.
  writer('<br><div id="warning_groups"></div>')
  if flags.byproject:
    writer('<script>groupByProject();</script>')
  else:
    writer('<script>groupBySeverity();</script>')
  dump_fixed(writer, warn_patterns)
  dump_html_epilogue(writer)


def write_html(flags, project_names, warn_patterns, html_path, warning_messages,
               warning_links, warning_records, header_str):
  """Write warnings html file."""
  if html_path:
    with open(html_path, 'w') as outf:
      dump_html(flags, outf, warning_messages, warning_links, warning_records,
                header_str, warn_patterns, project_names)


def write_out_csv(flags, warn_patterns, warning_messages, warning_links,
                  warning_records, header_str, project_names):
  """Write warnings csv file."""
  if flags.csvpath:
    with open(flags.csvpath, 'w') as outf:
      dump_csv(csv.writer(outf, lineterminator='\n'), warn_patterns)

  if flags.csvwithdescription:
    with open(flags.csvwithdescription, 'w') as outf:
      dump_csv_with_description(csv.writer(outf, lineterminator='\n'),
                                warning_records, warning_messages,
                                warn_patterns, project_names)

  if flags.gencsv:
    dump_csv(csv.writer(sys.stdout, lineterminator='\n'), warn_patterns)
  else:
    dump_html(flags, sys.stdout, warning_messages, warning_links,
              warning_records, header_str, warn_patterns, project_names)
