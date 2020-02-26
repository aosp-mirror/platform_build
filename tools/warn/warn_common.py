# python3
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

"""Grep warnings messages and output HTML tables or warning counts in CSV.

Default is to output warnings in HTML tables grouped by warning severity.
Use option --byproject to output tables grouped by source file projects.
Use option --gencsv to output warning counts in CSV format.

Default input file is build.log, which can be changed with the --log flag.
"""

# List of important data structures and functions in this script.
#
# To parse and keep warning message in the input file:
#   severity:                classification of message severity
#   warn_patterns:
#   warn_patterns[w]['category']     tool that issued the warning, not used now
#   warn_patterns[w]['description']  table heading
#   warn_patterns[w]['members']      matched warnings from input
#   warn_patterns[w]['patterns']     regular expressions to match warnings
#   warn_patterns[w]['projects'][p]  number of warnings of pattern w in p
#   warn_patterns[w]['severity']     severity tuple
#   project_list[p][0]               project name
#   project_list[p][1]               regular expression to match a project path
#   project_patterns[p]              re.compile(project_list[p][1])
#   project_names[p]                 project_list[p][0]
#   warning_messages     array of each warning message, without source url
#   warning_links        array of each warning code search link; for 'chrome'
#   warning_records      array of [idx to warn_patterns,
#                                  idx to project_names,
#                                  idx to warning_messages,
#                                  idx to warning_links]
#   parse_input_file
#
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
import argparse
import cgi
import csv
import io
import multiprocessing
import os
import re
import sys

# pylint:disable=relative-beyond-top-level
from . import android_project_list
from . import chrome_project_list
from . import cpp_warn_patterns as cpp_patterns
from . import java_warn_patterns as java_patterns
from . import make_warn_patterns as make_patterns
from . import other_warn_patterns as other_patterns
from . import tidy_warn_patterns as tidy_patterns
# pylint:disable=g-importing-member
from .severity import Severity


def parse_args(use_google3):
  """Define and parse the args. Return the parse_args() result."""
  parser = argparse.ArgumentParser(
      description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
  parser.add_argument('--capacitor_path', default='',
                      help='Save capacitor warning file to the passed absolute'
                      ' path')
  # csvpath has a different naming than the above path because historically the
  # original Android script used csvpath, so other scripts rely on it
  parser.add_argument('--csvpath', default='',
                      help='Save CSV warning file to the passed path')
  parser.add_argument('--gencsv', action='store_true',
                      help='Generate CSV file with number of various warnings')
  parser.add_argument('--byproject', action='store_true',
                      help='Separate warnings in HTML output by project names')
  parser.add_argument('--url', default='',
                      help='Root URL of an Android source code tree prefixed '
                      'before files in warnings')
  parser.add_argument('--separator', default='?l=',
                      help='Separator between the end of a URL and the line '
                      'number argument. e.g. #')
  parser.add_argument('--processes', default=multiprocessing.cpu_count(),
                      type=int,
                      help='Number of parallel processes to process warnings')
  # Old Android build scripts call warn.py without --platform,
  # so the default platform is set to 'android'.
  parser.add_argument('--platform', default='android',
                      choices=['chrome', 'android'],
                      help='Platform of the build log')
  # Old Android build scripts call warn.py with only a build.log file path.
  parser.add_argument('--log', help='Path to build log file')
  parser.add_argument(dest='buildlog', metavar='build.log',
                      default='build.log', nargs='?',
                      help='Path to build.log file')
  flags = parser.parse_args()
  if not flags.log:
    flags.log = flags.buildlog
  if not use_google3 and not os.path.exists(flags.log):
    sys.exit('Cannot find log file: ' + flags.log)
  return flags


def get_project_names(project_list):
  """Get project_names from project_list."""
  return [p[0] for p in project_list]


html_head_scripts = """\
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
  writer(html_head_scripts)
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
  # pylint:disable=g-complex-comprehension
  warnings = {p: {s.value: 0 for s in Severity.levels} for p in project_names}
  for i in warn_patterns:
    s = i['severity'].value
    for p in i['projects']:
      warnings[p][s] += i['projects'][p]
  return warnings


def get_total_by_project(warnings, project_names):
  """Returns dict, project as key and # warnings for that project as value."""
  # pylint:disable=g-complex-comprehension
  return {
      p: sum(warnings[p][s.value] for s in Severity.levels)
      for p in project_names
  }


def get_total_by_severity(warnings, project_names):
  """Returns dict, severity as key and # warnings of that severity as value."""
  # pylint:disable=g-complex-comprehension
  return {
      s.value: sum(warnings[p][s.value] for p in project_names)
      for s in Severity.levels
  }


def emit_table_header(total_by_severity):
  """Returns list of HTML-formatted content for severity stats."""

  stats_header = ['Project']
  for s in Severity.levels:
    if total_by_severity[s.value]:
      stats_header.append(
          '<span style=\'background-color:{}\'>{}</span>'.format(
              s.color, s.column_header))
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
  for p in project_names:
    if total_by_project[p]:
      one_row = [p]
      for s in Severity.levels:
        if total_by_severity[s.value]:
          one_row.append(warnings[p][s.value])
      one_row.append(total_by_project[p])
      stats_rows.append(one_row)
      total_all_projects += total_by_project[p]
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
  for s in Severity.levels:
    if total_by_severity[s.value]:
      one_row.append(total_by_severity[s.value])
      total_all_severities += total_by_severity[s.value]
  one_row.append(total_all_projects)
  stats_rows.append(one_row)
  writer('<script>')
  emit_const_string_array('StatsHeader', stats_header, writer)
  emit_const_object_array('StatsRows', stats_rows, writer)
  writer(draw_table_javascript)
  writer('</script>')


def emit_stats_by_project(writer, warn_patterns, project_names):
  """Dump a google chart table of warnings per project and severity."""

  warnings = create_warnings(warn_patterns, project_names)
  total_by_project = get_total_by_project(warnings, project_names)
  total_by_severity = get_total_by_severity(warnings, project_names)
  stats_header = emit_table_header(total_by_severity)
  total_all_projects, stats_rows = \
    emit_row_counts_per_project(warnings, total_by_project, total_by_severity, project_names)
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
    t = text[:-1] if text[-1] == '\n' else text
    writer('<tr><td class="c' + str(cur_row_class) + '">' + t + '</td></tr>')
  writer('</table></div>')
  writer('</blockquote>')


def write_severity(csvwriter, sev, kind, warn_patterns):
  """Count warnings of given severity and write CSV entries to writer."""
  total = 0
  for pattern in warn_patterns:
    if pattern['severity'] == sev and pattern['members']:
      n = len(pattern['members'])
      total += n
      warning = kind + ': ' + (pattern['description'] or '?')
      csvwriter.writerow([n, '', warning])
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
  for s in Severity.levels:
    total += write_severity(csvwriter, s, s.column_header, warn_patterns)
  csvwriter.writerow([total, '', 'All warnings'])


def find_project_index(line, project_patterns):
  for i, p in enumerate(project_patterns):
    if p.match(line):
      return i
  return -1


def classify_one_warning(warning, link, results, project_patterns,
                         warn_patterns):
  """Classify one warning line."""
  for i, w in enumerate(warn_patterns):
    for cpat in w['compiled_patterns']:
      if cpat.match(warning):
        p = find_project_index(warning, project_patterns)
        results.append([warning, link, i, p])
        return
      else:
        # If we end up here, there was a problem parsing the log
        # probably caused by 'make -j' mixing the output from
        # 2 or more concurrent compiles
        pass


def remove_prefix(s, sub):
  """Remove everything before last occurrence of substring sub in string s."""
  if sub in s:
    inc_sub = s.rfind(sub)
    return s[inc_sub:]
  return s


# TODO(emmavukelj): Don't have any generate_*_cs_link functions call
# normalize_path a second time (the first time being in parse_input_file)
def generate_cs_link(warning_line, flags, android_root=None):
  if flags.platform == 'chrome':
    return generate_chrome_cs_link(warning_line, flags)
  if flags.platform == 'android':
    return generate_android_cs_link(warning_line, flags, android_root)
  return 'https://cs.corp.google.com/'


def generate_android_cs_link(warning_line, flags, android_root):
  """Generate the code search link for a warning line in Android."""
  # max_splits=2 -> only 3 items
  raw_path, line_number_str, _ = warning_line.split(':', 2)
  normalized_path = normalize_path(raw_path, flags, android_root)
  if not flags.url:
    return normalized_path
  link_path = flags.url + '/' + normalized_path
  if line_number_str.isdigit():
    link_path += flags.separator + line_number_str
  return link_path


def generate_chrome_cs_link(warning_line, flags):
  """Generate the code search link for a warning line in Chrome."""
  split_line = warning_line.split(':')
  raw_path = split_line[0]
  normalized_path = normalize_path(raw_path, flags)
  link_base = 'https://cs.chromium.org/'
  link_add = 'chromium'
  link_path = None

  # Basically just going through a few specific directory cases and specifying
  # the proper behavior for that case. This list of cases was accumulated
  # through trial and error manually going through the warnings.
  #
  # This code pattern of using case-specific "if"s instead of "elif"s looks
  # possibly accidental and mistaken but it is intentional because some paths
  # fall under several cases (e.g. third_party/lib/nghttp2_frame.c) and for
  # those we want the most specific case to be applied. If there is reliable
  # knowledge of exactly where these occur, this could be changed to "elif"s
  # but there is no reliable set of paths falling under multiple cases at the
  # moment.
  if '/src/third_party' in raw_path:
    link_path = remove_prefix(raw_path, '/src/third_party/')
  if '/chrome_root/src_internal/' in raw_path:
    link_path = remove_prefix(raw_path, '/chrome_root/src_internal/')
    link_path = link_path[len('/chrome_root'):]  # remove chrome_root
  if '/chrome_root/src/' in raw_path:
    link_path = remove_prefix(raw_path, '/chrome_root/src/')
    link_path = link_path[len('/chrome_root'):]  # remove chrome_root
  if '/libassistant/' in raw_path:
    link_add = 'eureka_internal/chromium/src'
    link_base = 'https://cs.corp.google.com/'  # internal data
    link_path = remove_prefix(normalized_path, '/libassistant/')
  if raw_path.startswith('gen/'):
    link_path = '/src/out/Debug/gen/' + normalized_path
  if '/gen/' in raw_path:
    return '%s?q=file:%s' % (link_base, remove_prefix(normalized_path, '/gen/'))

  if not link_path and (raw_path.startswith('src/') or
                        raw_path.startswith('src_internal/')):
    link_path = '/%s' % raw_path

  if not link_path:  # can't find specific link, send a query
    return '%s?q=file:%s' % (link_base, normalized_path)

  line_number = int(split_line[1])
  link = '%s%s%s?l=%d' % (link_base, link_add, link_path, line_number)
  return link


def find_warn_py_and_android_root(path):
  """Return android source root path if warn.py is found."""
  parts = path.split('/')
  for idx in reversed(range(2, len(parts))):
    root_path = '/'.join(parts[:idx])
    # Android root directory should contain this script.
    if os.path.exists(root_path + '/build/make/tools/warn.py'):
      return root_path
  return ''


def find_android_root(buildlog):
  """Guess android source root from common prefix of file paths."""
  # Use the longest common prefix of the absolute file paths
  # of the first 10000 warning messages as the android_root.
  warning_lines = []
  warning_pattern = re.compile('^/[^ ]*/[^ ]*: warning: .*')
  count = 0
  for line in buildlog:
    if warning_pattern.match(line):
      warning_lines.append(line)
      count += 1
      if count > 9999:
        break
      # Try to find warn.py and use its location to find
      # the source tree root.
      if count < 100:
        path = os.path.normpath(re.sub(':.*$', '', line))
        android_root = find_warn_py_and_android_root(path)
        if android_root:
          return android_root
  # Do not use common prefix of a small number of paths.
  if count > 10:
    # pytype: disable=wrong-arg-types
    root_path = os.path.commonprefix(warning_lines)
    # pytype: enable=wrong-arg-types
    if len(root_path) > 2 and root_path[len(root_path) - 1] == '/':
      return root_path[:-1]
  return ''


def remove_android_root_prefix(path, android_root):
  """Remove android_root prefix from path if it is found."""
  if path.startswith(android_root):
    return path[1 + len(android_root):]
  return path


def normalize_path(path, flags, android_root=None):
  """Normalize file path relative to src/ or src-internal/ directory."""
  path = os.path.normpath(path)

  if flags.platform == 'android':
    if android_root:
      return remove_android_root_prefix(path, android_root)
    return path

  # Remove known prefix of root path and normalize the suffix.
  idx = path.find('chrome_root/')
  if idx >= 0:
    # remove chrome_root/, we want path relative to that
    return path[idx + len('chrome_root/'):]
  else:
    return path


def normalize_warning_line(line, flags, android_root=None):
  """Normalize file path relative to src directory in a warning line."""
  line = re.sub(u'[\u2018\u2019]', '\'', line)
  # replace non-ASCII chars to spaces
  line = re.sub(u'[^\x00-\x7f]', ' ', line)
  line = line.strip()
  first_column = line.find(':')
  return normalize_path(line[:first_column], flags,
                        android_root) + line[first_column:]


def parse_input_file_chrome(infile, flags):
  """Parse Chrome input file, collect parameters and warning lines."""
  platform_version = 'unknown'
  board_name = 'unknown'
  architecture = 'unknown'

  # only handle warning lines of format 'file_path:line_no:col_no: warning: ...'
  chrome_warning_pattern = r'^[^ ]*/[^ ]*:[0-9]+:[0-9]+: warning: .*'

  warning_pattern = re.compile(chrome_warning_pattern)

  # Collect all unique warning lines
  # Remove the duplicated warnings save ~8% of time when parsing
  # one typical build log than before
  unique_warnings = dict()
  for line in infile:
    if warning_pattern.match(line):
      normalized_line = normalize_warning_line(line, flags)
      if normalized_line not in unique_warnings:
        unique_warnings[normalized_line] = generate_cs_link(line, flags)
    elif (platform_version == 'unknown' or board_name == 'unknown' or
          architecture == 'unknown'):
      m = re.match(r'.+Package:.+chromeos-base/chromeos-chrome-', line)
      if m is not None:
        platform_version = 'R' + line.split('chrome-')[1].split('_')[0]
        continue
      m = re.match(r'.+Source\sunpacked\sin\s(.+)', line)
      if m is not None:
        board_name = m.group(1).split('/')[2]
        continue
      m = re.match(r'.+USE:\s*([^\s]*).*', line)
      if m is not None:
        architecture = m.group(1)
        continue

  header_str = '%s - %s - %s' % (platform_version, board_name, architecture)
  return unique_warnings, header_str


def add_normalized_line_to_warnings(line, flags, android_root, unique_warnings):
  """Parse/normalize path, updating warning line and add to warnings dict."""
  normalized_line = normalize_warning_line(line, flags, android_root)
  if normalized_line not in unique_warnings:
    unique_warnings[normalized_line] = generate_cs_link(line, flags,
                                                        android_root)
  return unique_warnings


def parse_input_file_android(infile, flags):
  """Parse Android input file, collect parameters and warning lines."""
  platform_version = 'unknown'
  target_product = 'unknown'
  target_variant = 'unknown'
  android_root = find_android_root(infile)
  infile.seek(0)

  # rustc warning messages have two lines that should be combined:
  #     warning: description
  #        --> file_path:line_number:column_number
  # Some warning messages have no file name:
  #     warning: macro replacement list ... [bugprone-macro-parentheses]
  # Some makefile warning messages have no line number:
  #     some/path/file.mk: warning: description
  # C/C++ compiler warning messages have line and column numbers:
  #     some/path/file.c:line_number:column_number: warning: description
  warning_pattern = re.compile('(^[^ ]*/[^ ]*: warning: .*)|(^warning: .*)')
  warning_without_file = re.compile('^warning: .*')
  rustc_file_position = re.compile('^[ ]+--> [^ ]*/[^ ]*:[0-9]+:[0-9]+')

   # Collect all unique warning lines
  # Remove the duplicated warnings save ~8% of time when parsing
  # one typical build log than before
  unique_warnings = dict()
  line_counter = 0
  prev_warning = ''
  for line in infile:
    if prev_warning:
      if rustc_file_position.match(line):
        # must be a rustc warning, combine 2 lines into one warning
        line = line.strip().replace('--> ', '') + ': ' + prev_warning
        unique_warnings = add_normalized_line_to_warnings(
            line, flags, android_root, unique_warnings)
        prev_warning = ''
        continue
      # add prev_warning, and then process the current line
      prev_warning = 'unknown_source_file: ' + prev_warning
      unique_warnings = add_normalized_line_to_warnings(
          prev_warning, flags, android_root, unique_warnings)
      prev_warning = ''

    if warning_pattern.match(line):
      if warning_without_file.match(line):
        # save this line and combine it with the next line
        prev_warning = line
      else:
        unique_warnings = add_normalized_line_to_warnings(
            line, flags, android_root, unique_warnings)
      continue

    if line_counter < 100:
      # save a little bit of time by only doing this for the first few lines
      line_counter += 1
      m = re.search('(?<=^PLATFORM_VERSION=).*', line)
      if m is not None:
        platform_version = m.group(0)
      m = re.search('(?<=^TARGET_PRODUCT=).*', line)
      if m is not None:
        target_product = m.group(0)
      m = re.search('(?<=^TARGET_BUILD_VARIANT=).*', line)
      if m is not None:
        target_variant = m.group(0)
      m = re.search('(?<=^TOP=).*', line)
      if m is not None:
        android_root = m.group(1)

  if android_root:
    new_unique_warnings = dict()
    for warning_line in unique_warnings:
      normalized_line = normalize_warning_line(warning_line, flags,
                                               android_root)
      new_unique_warnings[normalized_line] = generate_android_cs_link(
          warning_line, flags, android_root)
    unique_warnings = new_unique_warnings

  header_str = '%s - %s - %s' % (platform_version, target_product,
                                 target_variant)
  return unique_warnings, header_str


def parse_input_file(infile, flags):
  if flags.platform == 'chrome':
    return parse_input_file_chrome(infile, flags)
  if flags.platform == 'android':
    return parse_input_file_android(infile, flags)
  raise RuntimeError('parse_input_file not defined for platform %s' %
                     flags.platform)


# Return s with escaped backslash and quotation characters.
def escape_string(s):
  return s.replace('\\', '\\\\').replace('"', '\\"')


# Return s without trailing '\n' and escape the quotation characters.
def strip_escape_string(s):
  if not s:
    return s
  s = s[:-1] if s[-1] == '\n' else s
  return escape_string(s)


def emit_warning_array(name, writer, warn_patterns):
  writer('var warning_{} = ['.format(name))
  for w in warn_patterns:
    if name == 'severity':
      writer('{},'.format(w[name].value))
    else:
      writer('{},'.format(w[name]))
  writer('];')


def emit_warning_arrays(writer, warn_patterns):
  emit_warning_array('severity', writer, warn_patterns)
  writer('var warning_description = [')
  for w in warn_patterns:
    if w['members']:
      writer('"{}",'.format(escape_string(w['description'])))
    else:
      writer('"",')  # no such warning
  writer('];')


scripts_for_warning_groups = """
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
  for n in array:
    writer(str(n) + ',')
  writer('];')


# Emit a JavaScript const string array.
def emit_const_string_array(name, array, writer):
  writer('const ' + name + ' = [')
  for s in array:
    writer('"' + strip_escape_string(s) + '",')
  writer('];')


# Emit a JavaScript const string array for HTML.
def emit_const_html_string_array(name, array, writer):
  writer('const ' + name + ' = [')
  for s in array:
    # Not using html.escape yet, to work for both python 2 and 3,
    # until all users switch to python 3.
    # pylint:disable=deprecated-method
    writer('"' + cgi.escape(strip_escape_string(s)) + '",')
  writer('];')


# Emit a JavaScript const object array.
def emit_const_object_array(name, array, writer):
  writer('const ' + name + ' = [')
  for x in array:
    writer(str(x) + ',')
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


draw_table_javascript = """
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
  writer(scripts_for_warning_groups)
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


def parse_compiler_output(compiler_output):
  """Parse compiler output for relevant info."""
  split_output = compiler_output.split(':', 3)  # 3 = max splits
  file_path = split_output[0]
  line_number = int(split_output[1])
  col_number = int(split_output[2].split(' ')[0])
  warning_message = split_output[3]
  return file_path, line_number, col_number, warning_message


def get_warn_patterns(platform):
  """Get and initialize warn_patterns."""
  warn_patterns = []
  if platform == 'chrome':
    warn_patterns = cpp_patterns.warn_patterns
  elif platform == 'android':
    warn_patterns = make_patterns.warn_patterns + cpp_patterns.warn_patterns + java_patterns.warn_patterns + tidy_patterns.warn_patterns + other_patterns.warn_patterns
  else:
    raise Exception('platform name %s is not valid' % platform)
  for w in warn_patterns:
    w['members'] = []
    # Each warning pattern has a 'projects' dictionary, that
    # maps a project name to number of warnings in that project.
    w['projects'] = {}
  return warn_patterns


def get_project_list(platform):
  """Return project list for appropriate platform."""
  if platform == 'chrome':
    return chrome_project_list.project_list
  if platform == 'android':
    return android_project_list.project_list
  raise Exception('platform name %s is not valid' % platform)


def parallel_classify_warnings(warning_data, args, project_names,
                               project_patterns, warn_patterns,
                               use_google3, create_launch_subprocs_fn,
                               classify_warnings_fn):
  """Classify all warning lines with num_cpu parallel processes."""
  num_cpu = args.processes
  group_results = []

  if num_cpu > 1:
    # set up parallel processing for this...
    warning_groups = [[] for _ in range(num_cpu)]
    i = 0
    for warning, link in warning_data.items():
      warning_groups[i].append((warning, link))
      i = (i + 1) % num_cpu
    arg_groups = [[] for _ in range(num_cpu)]
    for i, group in enumerate(warning_groups):
      arg_groups[i] = [{
          'group': group,
          'project_patterns': project_patterns,
          'warn_patterns': warn_patterns,
          'num_processes': num_cpu
      }]

    group_results = create_launch_subprocs_fn(num_cpu,
                                              classify_warnings_fn,
                                              arg_groups,
                                              group_results)
  else:
    group_results = []
    for warning, link in warning_data.items():
      classify_one_warning(warning, link, group_results,
                           project_patterns, warn_patterns)
    group_results = [group_results]

  warning_messages = []
  warning_links = []
  warning_records = []
  if use_google3:
    group_results = [group_results]
  for group_result in group_results:
    for result in group_result:
      for line, link, pattern_idx, project_idx in result:
        pattern = warn_patterns[pattern_idx]
        pattern['members'].append(line)
        message_idx = len(warning_messages)
        warning_messages.append(line)
        link_idx = len(warning_links)
        warning_links.append(link)
        warning_records.append([pattern_idx, project_idx, message_idx,
                                link_idx])
        pname = '???' if project_idx < 0 else project_names[project_idx]
        # Count warnings by project.
        if pname in pattern['projects']:
          pattern['projects'][pname] += 1
        else:
          pattern['projects'][pname] = 1
  return warning_messages, warning_links, warning_records


def write_html(flags, project_names, warn_patterns, html_path, warning_messages,
               warning_links, warning_records, header_str):
  """Write warnings html file."""
  if html_path:
    with open(html_path, 'w') as f:
      dump_html(flags, f, warning_messages, warning_links, warning_records,
                header_str, warn_patterns, project_names)


def write_out_csv(flags, warn_patterns, warning_messages, warning_links,
                  warning_records, header_str, project_names):
  """Write warnings csv file."""
  if flags.csvpath:
    with open(flags.csvpath, 'w') as f:
      dump_csv(csv.writer(f, lineterminator='\n'), warn_patterns)

  if flags.gencsv:
    dump_csv(csv.writer(sys.stdout, lineterminator='\n'), warn_patterns)
  else:
    dump_html(flags, sys.stdout, warning_messages, warning_links,
              warning_records, header_str, warn_patterns, project_names)


def process_log(logfile, flags, project_names, project_patterns, warn_patterns,
                html_path, use_google3, create_launch_subprocs_fn,
                classify_warnings_fn, logfile_object):
  # pylint: disable=g-doc-args
  # pylint: disable=g-doc-return-or-yield
  """Function that handles processing of a log.

  This is isolated into its own function (rather than just taking place in main)
  so that it can be used by both warn.py and the borg job process_gs_logs.py, to
  avoid duplication of code.
  Note that if the arguments to this function change, process_gs_logs.py must
  be updated accordingly.
  """
  if logfile_object is None:
    with io.open(logfile, encoding='utf-8') as log:
      warning_lines_and_links, header_str = parse_input_file(log, flags)
  else:
    warning_lines_and_links, header_str = parse_input_file(
        logfile_object, flags)
  warning_messages, warning_links, warning_records = parallel_classify_warnings(
      warning_lines_and_links, flags, project_names, project_patterns,
      warn_patterns, use_google3, create_launch_subprocs_fn,
      classify_warnings_fn)

  write_html(flags, project_names, warn_patterns, html_path,
             warning_messages, warning_links, warning_records,
             header_str)

  return warning_messages, warning_links, warning_records, header_str


def common_main(use_google3, create_launch_subprocs_fn, classify_warnings_fn,
                logfile_object=None):
  """Shared main function for Google3 and non-Google3 versions of warn.py."""
  flags = parse_args(use_google3)
  warn_patterns = get_warn_patterns(flags.platform)
  project_list = get_project_list(flags.platform)

  project_names = get_project_names(project_list)
  project_patterns = [re.compile(p[1]) for p in project_list]

  # html_path=None because we output html below if not outputting CSV
  warning_messages, warning_links, warning_records, header_str = process_log(
      logfile=flags.log, flags=flags, project_names=project_names,
      project_patterns=project_patterns, warn_patterns=warn_patterns,
      html_path=None, use_google3=use_google3,
      create_launch_subprocs_fn=create_launch_subprocs_fn,
      classify_warnings_fn=classify_warnings_fn,
      logfile_object=logfile_object)

  write_out_csv(flags, warn_patterns, warning_messages, warning_links,
                warning_records, header_str, project_names)

  # Return these values, so that caller can use them, if desired.
  return flags, warning_messages, warning_records, warn_patterns
