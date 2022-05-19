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
import argparse
import io
import multiprocessing
import os
import re
import sys

# pylint:disable=relative-beyond-top-level,no-name-in-module
# suppress false positive of no-name-in-module warnings
from . import android_project_list
from . import chrome_project_list
from . import cpp_warn_patterns as cpp_patterns
from . import html_writer
from . import java_warn_patterns as java_patterns
from . import make_warn_patterns as make_patterns
from . import other_warn_patterns as other_patterns
from . import tidy_warn_patterns as tidy_patterns


# Location of this file is used to guess the root of Android source tree.
THIS_FILE_PATH = 'build/make/tools/warn/warn_common.py'


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
  parser.add_argument('--csvwithdescription', default='',
                      help="""Save CSV warning file to the passed path this csv
                            will contain all the warning descriptions""")
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


def find_project_index(line, project_patterns):
  """Return the index to the project pattern array."""
  for idx, pattern in enumerate(project_patterns):
    if pattern.match(line):
      return idx
  return -1


def classify_one_warning(warning, link, results, project_patterns,
                         warn_patterns):
  """Classify one warning line."""
  for idx, pattern in enumerate(warn_patterns):
    for cpat in pattern['compiled_patterns']:
      if cpat.match(warning):
        project_idx = find_project_index(warning, project_patterns)
        results.append([warning, link, idx, project_idx])
        return
  # If we end up here, there was a problem parsing the log
  # probably caused by 'make -j' mixing the output from
  # 2 or more concurrent compiles


def remove_prefix(src, sub):
  """Remove everything before last occurrence of substring sub in string src."""
  if sub in src:
    inc_sub = src.rfind(sub)
    return src[inc_sub:]
  return src


# TODO(emmavukelj): Don't have any generate_*_cs_link functions call
# normalize_path a second time (the first time being in parse_input_file)
def generate_cs_link(warning_line, flags, android_root=None):
  """Try to add code search HTTP URL prefix."""
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


def find_this_file_and_android_root(path):
  """Return android source root path if this file is found."""
  parts = path.split('/')
  for idx in reversed(range(2, len(parts))):
    root_path = '/'.join(parts[:idx])
    # Android root directory should contain this script.
    if os.path.exists(root_path + '/' + THIS_FILE_PATH):
      return root_path
  return ''


def find_android_root_top_dirs(root_dir):
  """Return a list of directories under the root_dir, if it exists."""
  # Root directory should contain at least build/make and build/soong.
  if (not os.path.isdir(root_dir + '/build/make') or
      not os.path.isdir(root_dir + '/build/soong')):
    return None
  return list(filter(lambda d: os.path.isdir(root_dir + '/' + d),
                     os.listdir(root_dir)))


def find_android_root(buildlog):
  """Guess android source root from common prefix of file paths."""
  # Use the longest common prefix of the absolute file paths
  # of the first 10000 warning messages as the android_root.
  warning_lines = []
  warning_pattern = re.compile('^/[^ ]*/[^ ]*: warning: .*')
  count = 0
  for line in buildlog:
    # We want to find android_root of a local build machine.
    # Do not use RBE warning lines, which has '/b/f/w/' path prefix.
    # Do not use /tmp/ file warnings.
    if ('/b/f/w' not in line and not line.startswith('/tmp/') and
        warning_pattern.match(line)):
      warning_lines.append(line)
      count += 1
      if count > 9999:
        break
      # Try to find warn.py and use its location to find
      # the source tree root.
      if count < 100:
        path = os.path.normpath(re.sub(':.*$', '', line))
        android_root = find_this_file_and_android_root(path)
        if android_root:
          return android_root, find_android_root_top_dirs(android_root)
  # Do not use common prefix of a small number of paths.
  android_root = ''
  if count > 10:
    # pytype: disable=wrong-arg-types
    root_path = os.path.commonprefix(warning_lines)
    # pytype: enable=wrong-arg-types
    if len(root_path) > 2 and root_path[len(root_path) - 1] == '/':
      android_root = root_path[:-1]
  if android_root and os.path.isdir(android_root):
    return android_root, find_android_root_top_dirs(android_root)
  # When the build.log file is moved to a different machine where
  # android_root is not found, use the location of this script
  # to find the android source tree sub directories.
  if __file__.endswith('/' + THIS_FILE_PATH):
    script_root = __file__.replace('/' + THIS_FILE_PATH, '')
    return android_root, find_android_root_top_dirs(script_root)
  return android_root, None


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
  # Bug: http://198657613, This might need change to handle RBE output.
  chrome_warning_pattern = r'^[^ ]*/[^ ]*:[0-9]+:[0-9]+: warning: .*'

  warning_pattern = re.compile(chrome_warning_pattern)

  # Collect all unique warning lines
  unique_warnings = dict()
  for line in infile:
    if warning_pattern.match(line):
      normalized_line = normalize_warning_line(line, flags)
      if normalized_line not in unique_warnings:
        unique_warnings[normalized_line] = generate_cs_link(line, flags)
    elif (platform_version == 'unknown' or board_name == 'unknown' or
          architecture == 'unknown'):
      result = re.match(r'.+Package:.+chromeos-base/chromeos-chrome-', line)
      if result is not None:
        platform_version = 'R' + line.split('chrome-')[1].split('_')[0]
        continue
      result = re.match(r'.+Source\sunpacked\sin\s(.+)', line)
      if result is not None:
        board_name = result.group(1).split('/')[2]
        continue
      result = re.match(r'.+USE:\s*([^\s]*).*', line)
      if result is not None:
        architecture = result.group(1)
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
  # pylint:disable=too-many-locals,too-many-branches
  platform_version = 'unknown'
  target_product = 'unknown'
  target_variant = 'unknown'
  build_id = 'unknown'
  android_root, root_top_dirs = find_android_root(infile)
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
  rustc_file_position = re.compile('^[ ]+--> [^ ]*/[^ ]*:[0-9]+:[0-9]+')

  # If RBE was used, try to reclaim some warning lines (from stdout)
  # that contain leading characters from stderr.
  # The leading characters can be any character, including digits and spaces.

  # If a warning line's source file path contains the special RBE prefix
  # /b/f/w/, we can remove all leading chars up to and including the "/b/f/w/".
  bfw_warning_pattern = re.compile('.*/b/f/w/([^ ]*: warning: .*)')

  # When android_root is known and available, we find its top directories
  # and remove all leading chars before a top directory name.
  # We assume that the leading chars from stderr do not contain "/".
  # For example,
  #   10external/...
  #   12 warningsexternal/...
  #   413 warningexternal/...
  #   5 warnings generatedexternal/...
  #   Suppressed 1000 warnings (packages/modules/...
  if root_top_dirs:
    extra_warning_pattern = re.compile(
        '^.[^/]*((' + '|'.join(root_top_dirs) +
        ')/[^ ]*: warning: .*)')
  else:
    extra_warning_pattern = re.compile('^[^/]* ([^ /]*/[^ ]*: warning: .*)')

  # Collect all unique warning lines
  unique_warnings = dict()
  checked_warning_lines = dict()
  line_counter = 0
  prev_warning = ''
  for line in infile:
    line_counter += 1
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

    # re.match is slow, with several warning line patterns and
    # long input lines like "TIMEOUT: ...".
    # We save significant time by skipping non-warning lines.
    # But do not skip the first 100 lines, because we want to
    # catch build variables.
    if line_counter > 100 and line.find('warning: ') < 0:
      continue

    # A large clean build output can contain up to 90% of duplicated
    # "warning:" lines. If we can skip them quickly, we can
    # speed up this for-loop 3X to 5X.
    if line in checked_warning_lines:
      continue
    checked_warning_lines[line] = True

    # Clean up extra prefix that could be introduced when RBE was used.
    if '/b/f/w/' in line:
      result = bfw_warning_pattern.search(line)
    else:
      result = extra_warning_pattern.search(line)
    if result is not None:
      line = result.group(1)

    if warning_pattern.match(line):
      if line.startswith('warning: '):
        # save this line and combine it with the next line
        prev_warning = line
      else:
        unique_warnings = add_normalized_line_to_warnings(
            line, flags, android_root, unique_warnings)
      continue

    if line_counter < 100:
      # save a little bit of time by only doing this for the first few lines
      result = re.search('(?<=^PLATFORM_VERSION=).*', line)
      if result is not None:
        platform_version = result.group(0)
        continue
      result = re.search('(?<=^TARGET_PRODUCT=).*', line)
      if result is not None:
        target_product = result.group(0)
        continue
      result = re.search('(?<=^TARGET_BUILD_VARIANT=).*', line)
      if result is not None:
        target_variant = result.group(0)
        continue
      result = re.search('(?<=^BUILD_ID=).*', line)
      if result is not None:
        build_id = result.group(0)
        continue

  if android_root:
    new_unique_warnings = dict()
    for warning_line in unique_warnings:
      normalized_line = normalize_warning_line(warning_line, flags,
                                               android_root)
      new_unique_warnings[normalized_line] = generate_android_cs_link(
          warning_line, flags, android_root)
    unique_warnings = new_unique_warnings

  header_str = '%s - %s - %s (%s)' % (
      platform_version, target_product, target_variant, build_id)
  return unique_warnings, header_str


def parse_input_file(infile, flags):
  """Parse one input file for chrome or android."""
  if flags.platform == 'chrome':
    return parse_input_file_chrome(infile, flags)
  if flags.platform == 'android':
    return parse_input_file_android(infile, flags)
  raise RuntimeError('parse_input_file not defined for platform %s' %
                     flags.platform)


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
    warn_patterns = (make_patterns.warn_patterns + cpp_patterns.warn_patterns +
                     java_patterns.warn_patterns + tidy_patterns.warn_patterns +
                     other_patterns.warn_patterns)
  else:
    raise Exception('platform name %s is not valid' % platform)
  for pattern in warn_patterns:
    pattern['members'] = []
    # Each warning pattern has a 'projects' dictionary, that
    # maps a project name to number of warnings in that project.
    pattern['projects'] = {}
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
  # pylint:disable=too-many-arguments,too-many-locals
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


def process_log(logfile, flags, project_names, project_patterns, warn_patterns,
                html_path, use_google3, create_launch_subprocs_fn,
                classify_warnings_fn, logfile_object):
  # pylint does not recognize g-doc-*
  # pylint: disable=bad-option-value,g-doc-args
  # pylint: disable=bad-option-value,g-doc-return-or-yield
  # pylint: disable=too-many-arguments,too-many-locals
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

  html_writer.write_html(flags, project_names, warn_patterns, html_path,
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

  html_writer.write_out_csv(flags, warn_patterns, warning_messages,
                            warning_links, warning_records, header_str,
                            project_names)

  # Return these values, so that caller can use them, if desired.
  return flags, warning_messages, warning_records, warn_patterns
