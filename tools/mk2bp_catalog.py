#!/usr/bin/env python3

"""
Command to print info about makefiles remaining to be converted to soong.

See usage / argument parsing below for commandline options.
"""

import argparse
import csv
import itertools
import json
import os
import re
import sys

DIRECTORY_PATTERNS = [x.split("/") for x in (
  "device/*",
  "frameworks/*",
  "hardware/*",
  "packages/*",
  "vendor/*",
  "*",
)]

def match_directory_group(pattern, filename):
  match = []
  filename = filename.split("/")
  if len(filename) < len(pattern):
    return None
  for i in range(len(pattern)):
    pattern_segment = pattern[i]
    filename_segment = filename[i]
    if pattern_segment == "*" or pattern_segment == filename_segment:
      match.append(filename_segment)
    else:
      return None
  if match:
    return os.path.sep.join(match)
  else:
    return None

def directory_group(filename):
  for pattern in DIRECTORY_PATTERNS:
    match = match_directory_group(pattern, filename)
    if match:
      return match
  return os.path.dirname(filename)

class Analysis(object):
  def __init__(self, filename, line_matches):
    self.filename = filename;
    self.line_matches = line_matches

def analyze_lines(filename, lines, func):
  line_matches = []
  for i in range(len(lines)):
    line = lines[i]
    stripped = line.strip()
    if stripped.startswith("#"):
      continue
    if func(stripped):
      line_matches.append((i+1, line))
  if line_matches:
    return Analysis(filename, line_matches);

def analyze_has_conditional(line):
  return (line.startswith("ifeq") or line.startswith("ifneq")
          or line.startswith("ifdef") or line.startswith("ifndef"))

NORMAL_INCLUDES = [re.compile(pattern) for pattern in (
  "include \$+\(CLEAR_VARS\)", # These are in defines which are tagged separately
  "include \$+\(BUILD_.*\)",
  "include \$\(call first-makefiles-under, *\$\(LOCAL_PATH\)\)",
  "include \$\(call all-subdir-makefiles\)",
  "include \$\(all-subdir-makefiles\)",
  "include \$\(call all-makefiles-under, *\$\(LOCAL_PATH\)\)",
  "include \$\(call all-makefiles-under, *\$\(call my-dir\).*\)",
  "include \$\(BUILD_SYSTEM\)/base_rules.mk", # called out separately
  "include \$\(call all-named-subdir-makefiles,.*\)",
  "include \$\(subdirs\)",
)]
def analyze_has_wacky_include(line):
  if not (line.startswith("include") or line.startswith("-include")
          or line.startswith("sinclude")):
    return False
  for matcher in NORMAL_INCLUDES:
    if matcher.fullmatch(line):
      return False
  return True

BASE_RULES_RE = re.compile("include \$\(BUILD_SYSTEM\)/base_rules.mk")

class Analyzer(object):
  def __init__(self, title, func):
    self.title = title;
    self.func = func


ANALYZERS = (
  Analyzer("ifeq / ifneq", analyze_has_conditional),
  Analyzer("Wacky Includes", analyze_has_wacky_include),
  Analyzer("Calls base_rules", lambda line: BASE_RULES_RE.fullmatch(line)),
  Analyzer("Calls define", lambda line: line.startswith("define ")),
  Analyzer("Has ../", lambda line: "../" in line),
  Analyzer("dist-for-&#8203;goals", lambda line: "dist-for-goals" in line),
  Analyzer(".PHONY", lambda line: ".PHONY" in line),
  Analyzer("render-&#8203;script", lambda line: ".rscript" in line),
  Analyzer("vts src", lambda line: ".vts" in line),
  Analyzer("COPY_&#8203;HEADERS", lambda line: "LOCAL_COPY_HEADERS" in line),
)

class Summary(object):
  def __init__(self):
    self.makefiles = dict()
    self.directories = dict()

  def Add(self, makefile):
    self.makefiles[makefile.filename] = makefile
    self.directories.setdefault(directory_group(makefile.filename), []).append(makefile)

class Makefile(object):
  def __init__(self, filename):
    self.filename = filename

    # Analyze the file
    with open(filename, "r", errors="ignore") as f:
      try:
        lines = f.readlines()
      except UnicodeDecodeError as ex:
        sys.stderr.write("Filename: %s\n" % filename)
        raise ex
    lines = [line.strip() for line in lines]

    self.analyses = dict([(analyzer, analyze_lines(filename, lines, analyzer.func)) for analyzer
        in ANALYZERS])

def find_android_mk():
  cwd = os.getcwd()
  for root, dirs, files in os.walk(cwd):
    for filename in files:
      if filename == "Android.mk":
        yield os.path.join(root, filename)[len(cwd) + 1:]
    for ignore in (".git", ".repo"):
      if ignore in dirs:
        dirs.remove(ignore)

def is_aosp(dirname):
  for d in ("device/sample", "hardware/interfaces", "hardware/libhardware",
          "hardware/ril"):
    if dirname.startswith(d):
      return True
  for d in ("device/", "hardware/", "vendor/"):
    if dirname.startswith(d):
      return False
  return True

def is_google(dirname):
  for d in ("device/google",
            "hardware/google",
            "test/sts",
            "vendor/auto",
            "vendor/google",
            "vendor/unbundled_google",
            "vendor/widevine",
            "vendor/xts"):
    if dirname.startswith(d):
      return True
  return False

def is_clean(makefile):
  for analysis in makefile.analyses.values():
    if analysis:
      return False
  return True

def clean_and_only_blocked_by_clean(soong, all_makefiles, makefile):
  if not is_clean(makefile):
    return False
  modules = soong.reverse_makefiles[makefile.filename]
  for module in modules:
    for dep in soong.transitive_deps(module):
      for filename in soong.makefiles.get(dep, []):
        m = all_makefiles.get(filename)
        if m and not is_clean(m):
          return False
  return True

class Annotations(object):
  def __init__(self):
    self.entries = []
    self.count = 0

  def Add(self, makefiles, modules):
    self.entries.append((makefiles, modules))
    self.count += 1
    return self.count-1

class SoongData(object):
  def __init__(self, reader):
    """Read the input file and store the modules and dependency mappings.
    """
    self.problems = dict()
    self.deps = dict()
    self.reverse_deps = dict()
    self.module_types = dict()
    self.makefiles = dict()
    self.reverse_makefiles = dict()
    self.installed = dict()
    self.reverse_installed = dict()
    self.modules = set()

    for (module, module_type, problem, dependencies, makefiles, installed) in reader:
      self.modules.add(module)
      makefiles = [f for f in makefiles.strip().split(' ') if f != ""]
      self.module_types[module] = module_type
      self.problems[module] = problem
      self.deps[module] = [d for d in dependencies.strip().split(' ') if d != ""]
      for dep in self.deps[module]:
        if not dep in self.reverse_deps:
          self.reverse_deps[dep] = []
        self.reverse_deps[dep].append(module)
      self.makefiles[module] = makefiles
      for f in makefiles:
        self.reverse_makefiles.setdefault(f, []).append(module)
      for f in installed.strip().split(' '):
        self.installed[f] = module
        self.reverse_installed.setdefault(module, []).append(f)

  def transitive_deps(self, module):
    results = set()
    def traverse(module):
      for dep in self.deps.get(module, []):
        if not dep in results:
          results.add(dep)
          traverse(module)
    traverse(module)
    return results

  def contains_unblocked_modules(self, filename):
    for m in self.reverse_makefiles[filename]:
      if len(self.deps[m]) == 0:
        return True
    return False

  def contains_blocked_modules(self, filename):
    for m in self.reverse_makefiles[filename]:
      if len(self.deps[m]) > 0:
        return True
    return False

def count_deps(depsdb, module, seen):
  """Based on the depsdb, count the number of transitive dependencies.

  You can pass in an reversed dependency graph to count the number of
  modules that depend on the module."""
  count = 0
  seen.append(module)
  if module in depsdb:
    for dep in depsdb[module]:
      if dep in seen:
        continue
      count += 1 + count_deps(depsdb, dep, seen)
  return count

OTHER_PARTITON = "_other"
HOST_PARTITON = "_host"

def get_partition_from_installed(HOST_OUT_ROOT, PRODUCT_OUT, filename):
  host_prefix = HOST_OUT_ROOT + "/"
  device_prefix = PRODUCT_OUT + "/"

  if filename.startswith(host_prefix):
    return HOST_PARTITON

  elif filename.startswith(device_prefix):
    index = filename.find("/", len(device_prefix))
    if index < 0:
      return OTHER_PARTITON
    return filename[len(device_prefix):index]

  return OTHER_PARTITON

def format_module_link(module):
  return "<a class='ModuleLink' href='#module_%s'>%s</a>" % (module, module)

def format_module_list(modules):
  return "".join(["<div>%s</div>" % format_module_link(m) for m in modules])

def print_analysis_header(link, title):
  print("""
    <a name="%(link)s"></a>
    <h2>%(title)s</h2>
    <table>
      <tr>
        <th class="RowTitle">Directory</th>
        <th class="Count">Total</th>
        <th class="Count Clean">Easy</th>
        <th class="Count Clean">Unblocked Clean</th>
        <th class="Count Unblocked">Unblocked</th>
        <th class="Count Blocked">Blocked</th>
        <th class="Count Clean">Clean</th>
  """ % {
    "link": link,
    "title": title
  })
  for analyzer in ANALYZERS:
    print("""<th class="Count Warning">%s</th>""" % analyzer.title)
  print("      </tr>")

def main():
  parser = argparse.ArgumentParser(description="Info about remaining Android.mk files.")
  parser.add_argument("--device", type=str, required=True,
                      help="TARGET_DEVICE")
  parser.add_argument("--title", type=str,
                      help="page title")
  parser.add_argument("--codesearch", type=str,
                      default="https://cs.android.com/android/platform/superproject/+/master:",
                      help="page title")
  parser.add_argument("--out_dir", type=str,
                      default=None,
                      help="Equivalent of $OUT_DIR, which will also be checked if"
                        + " --out_dir is unset. If neither is set, default is"
                        + " 'out'.")
  parser.add_argument("--mode", type=str,
                      default="html",
                      help="output format: csv or html")

  args = parser.parse_args()

  # Guess out directory name
  if not args.out_dir:
    args.out_dir = os.getenv("OUT_DIR", "out")
  while args.out_dir.endswith("/") and len(args.out_dir) > 1:
    args.out_dir = args.out_dir[:-1]

  TARGET_DEVICE = args.device
  global HOST_OUT_ROOT
  HOST_OUT_ROOT = args.out_dir + "/host"
  global PRODUCT_OUT
  PRODUCT_OUT = args.out_dir + "/target/product/%s" % TARGET_DEVICE

  # Read target information
  # TODO: Pull from configurable location. This is also slightly different because it's
  # only a single build, where as the tree scanning we do below is all Android.mk files.
  with open("%s/obj/PACKAGING/soong_conversion_intermediates/soong_conv_data"
      % PRODUCT_OUT, "r", errors="ignore") as csvfile:
    soong = SoongData(csv.reader(csvfile))

  # Read the makefiles
  all_makefiles = dict()
  for filename, modules in soong.reverse_makefiles.items():
    if filename.startswith(args.out_dir + "/"):
      continue
    all_makefiles[filename] = Makefile(filename)

  if args.mode == "html":
    HtmlProcessor(args=args, soong=soong, all_makefiles=all_makefiles).execute()
  elif args.mode == "csv":
    CsvProcessor(args=args, soong=soong, all_makefiles=all_makefiles).execute()

class HtmlProcessor(object):
  def __init__(self, args, soong, all_makefiles):
    self.args = args
    self.soong = soong
    self.all_makefiles = all_makefiles
    self.annotations = Annotations()

  def execute(self):
    if self.args.title:
      page_title = self.args.title
    else:
      page_title = "Remaining Android.mk files"

    # Which modules are installed where
    modules_by_partition = dict()
    partitions = set()
    for installed, module in self.soong.installed.items():
      partition = get_partition_from_installed(HOST_OUT_ROOT, PRODUCT_OUT, installed)
      modules_by_partition.setdefault(partition, []).append(module)
      partitions.add(partition)

    print("""
    <html>
      <head>
        <title>%(page_title)s</title>
        <style type="text/css">
          body, table {
            font-family: Roboto, sans-serif;
            font-size: 9pt;
          }
          body {
            margin: 0;
            padding: 0;
            display: flex;
            flex-direction: column;
            height: 100vh;
          }
          #container {
            flex: 1;
            display: flex;
            flex-direction: row;
            overflow: hidden;
          }
          #tables {
            padding: 0 20px 40px 20px;
            overflow: scroll;
            flex: 2 2 600px;
          }
          #details {
            display: none;
            overflow: scroll;
            flex: 1 1 650px;
            padding: 0 20px 0 20px;
          }
          h1 {
            margin: 16px 0 16px 20px;
          }
          h2 {
            margin: 12px 0 4px 0;
          }
          .RowTitle {
            text-align: left;
            width: 200px;
            min-width: 200px;
          }
          .Count {
            text-align: center;
            width: 60px;
            min-width: 60px;
            max-width: 60px;
          }
          th.Clean,
          th.Unblocked {
            background-color: #1e8e3e;
          }
          th.Blocked {
            background-color: #d93025;
          }
          th.Warning {
            background-color: #e8710a;
          }
          th {
            background-color: #1a73e8;
            color: white;
            font-weight: bold;
          }
          td.Unblocked {
            background-color: #81c995;
          }
          td.Blocked {
            background-color: #f28b82;
          }
          td, th {
            padding: 2px 4px;
            border-right: 2px solid white;
          }
          tr.TotalRow td {
            background-color: white;
            border-right-color: white;
          }
          tr.AospDir td {
            background-color: #e6f4ea;
            border-right-color: #e6f4ea;
          }
          tr.GoogleDir td {
            background-color: #e8f0fe;
            border-right-color: #e8f0fe;
          }
          tr.PartnerDir td {
            background-color: #fce8e6;
            border-right-color: #fce8e6;
          }
          table {
            border-spacing: 0;
            border-collapse: collapse;
          }
          div.Makefile {
            margin: 12px 0 0 0;
          }
          div.Makefile:first {
            margin-top: 0;
          }
          div.FileModules {
            padding: 4px 0 0 20px;
          }
          td.LineNo {
            vertical-align: baseline;
            padding: 6px 0 0 20px;
            width: 50px;
            vertical-align: baseline;
          }
          td.LineText {
            vertical-align: baseline;
            font-family: monospace;
            padding: 6px 0 0 0;
          }
          a.CsLink {
            font-family: monospace;
          }
          div.Help {
            width: 550px;
          }
          table.HelpColumns tr {
            border-bottom: 2px solid white;
          }
          .ModuleName {
            vertical-align: baseline;
            padding: 6px 0 0 20px;
            width: 275px;
          }
          .ModuleDeps {
            vertical-align: baseline;
            padding: 6px 0 0 0;
          }
          table#Modules td {
            vertical-align: baseline;
          }
          tr.Alt {
            background-color: #ececec;
          }
          tr.Alt td {
            border-right-color: #ececec;
          }
          .AnalysisCol {
            width: 300px;
            padding: 2px;
            line-height: 21px;
          }
          .Analysis {
            color: white;
            font-weight: bold;
            background-color: #e8710a;
            border-radius: 6px;
            margin: 4px;
            padding: 2px 6px;
            white-space: nowrap;
          }
          .Nav {
            margin: 4px 0 16px 20px;
          }
          .NavSpacer {
            display: inline-block;
            width: 6px;
          }
          .ModuleDetails {
            margin-top: 20px;
          }
          .ModuleDetails td {
            vertical-align: baseline;
          }
        </style>
      </head>
      <body>
        <h1>%(page_title)s</h1>
        <div class="Nav">
          <a href='#help'>Help</a>
          <span class='NavSpacer'></span><span class='NavSpacer'> </span>
          Partitions:
    """ % {
      "page_title": page_title,
    })
    for partition in sorted(partitions):
      print("<a href='#partition_%s'>%s</a><span class='NavSpacer'></span>" % (partition, partition))

    print("""
          <span class='NavSpacer'></span><span class='NavSpacer'> </span>
          <a href='#summary'>Overall Summary</a>
        </div>
        <div id="container">
          <div id="tables">
          <a name="help"></a>
          <div class="Help">
            <p>
            This page analyzes the remaining Android.mk files in the Android Source tree.
            <p>
            The modules are first broken down by which of the device filesystem partitions
            they are installed to. This also includes host tools and testcases which don't
            actually reside in their own partition but convenitely group together.
            <p>
            The makefiles for each partition are further are grouped into a set of directories
            aritrarily picked to break down the problem size by owners.
            <ul style="width: 300px">
              <li style="background-color: #e6f4ea">AOSP directories are colored green.</li>
              <li style="background-color: #e8f0fe">Google directories are colored blue.</li>
              <li style="background-color: #fce8e6">Other partner directories are colored red.</li>
            </ul>
            Each of the makefiles are scanned for issues that are likely to come up during
            conversion to soong.  Clicking the number in each cell shows additional information,
            including the line that triggered the warning.
            <p>
            <table class="HelpColumns">
              <tr>
                <th>Total</th>
                <td>The total number of makefiles in this each directory.</td>
              </tr>
              <tr>
                <th class="Clean">Easy</th>
                <td>The number of makefiles that have no warnings themselves, and also
                    none of their dependencies have warnings either.</td>
              </tr>
              <tr>
                <th class="Clean">Unblocked Clean</th>
                <td>The number of makefiles that are both Unblocked and Clean.</td>
              </tr>

              <tr>
                <th class="Unblocked">Unblocked</th>
                <td>Makefiles containing one or more modules that don't have any
                    additional dependencies pending before conversion.</td>
              </tr>
              <tr>
                <th class="Blocked">Blocked</th>
                <td>Makefiles containiong one or more modules which <i>do</i> have
                    additional prerequesite depenedencies that are not yet converted.</td>
              </tr>
              <tr>
                <th class="Clean">Clean</th>
                <td>The number of makefiles that have none of the following warnings.</td>
              </tr>
              <tr>
                <th class="Warning">ifeq / ifneq</th>
                <td>Makefiles that use <code>ifeq</code> or <code>ifneq</code>. i.e.
                conditionals.</td>
              </tr>
              <tr>
                <th class="Warning">Wacky Includes</th>
                <td>Makefiles that <code>include</code> files other than the standard build-system
                    defined template and macros.</td>
              </tr>
              <tr>
                <th class="Warning">Calls base_rules</th>
                <td>Makefiles that include base_rules.mk directly.</td>
              </tr>
              <tr>
                <th class="Warning">Calls define</th>
                <td>Makefiles that define their own macros. Some of these are easy to convert
                    to soong <code>defaults</code>, but others are complex.</td>
              </tr>
              <tr>
                <th class="Warning">Has ../</th>
                <td>Makefiles containing the string "../" outside of a comment. These likely
                    access files outside their directories.</td>
              </tr>
              <tr>
                <th class="Warning">dist-for-goals</th>
                <td>Makefiles that call <code>dist-for-goals</code> directly.</td>
              </tr>
              <tr>
                <th class="Warning">.PHONY</th>
                <td>Makefiles that declare .PHONY targets.</td>
              </tr>
              <tr>
                <th class="Warning">renderscript</th>
                <td>Makefiles defining targets that depend on <code>.rscript</code> source files.</td>
              </tr>
              <tr>
                <th class="Warning">vts src</th>
                <td>Makefiles defining targets that depend on <code>.vts</code> source files.</td>
              </tr>
              <tr>
                <th class="Warning">COPY_HEADERS</th>
                <td>Makefiles using LOCAL_COPY_HEADERS.</td>
              </tr>
            </table>
            <p>
            Following the list of directories is a list of the modules that are installed on
            each partition. Potential issues from their makefiles are listed, as well as the
            total number of dependencies (both blocking that module and blocked by that module)
            and the list of direct dependencies.  Note: The number is the number of all transitive
            dependencies and the list of modules is only the direct dependencies.
          </div>
    """)

    overall_summary = Summary()

    # For each partition
    for partition in sorted(partitions):
      modules = modules_by_partition[partition]

      makefiles = set(itertools.chain.from_iterable(
          [self.soong.makefiles[module] for module in modules]))

      # Read makefiles
      summary = Summary()
      for filename in makefiles:
        makefile = self.all_makefiles.get(filename)
        if makefile:
          summary.Add(makefile)
          overall_summary.Add(makefile)

      # Categorize directories by who is responsible
      aosp_dirs = []
      google_dirs = []
      partner_dirs = []
      for dirname in sorted(summary.directories.keys()):
        if is_aosp(dirname):
          aosp_dirs.append(dirname)
        elif is_google(dirname):
          google_dirs.append(dirname)
        else:
          partner_dirs.append(dirname)

      print_analysis_header("partition_" + partition, partition)

      for dirgroup, rowclass in [(aosp_dirs, "AospDir"),
                                 (google_dirs, "GoogleDir"),
                                 (partner_dirs, "PartnerDir"),]:
        for dirname in dirgroup:
          self.print_analysis_row(summary, modules,
                               dirname, rowclass, summary.directories[dirname])

      self.print_analysis_row(summary, modules,
                           "Total", "TotalRow",
                           set(itertools.chain.from_iterable(summary.directories.values())))
      print("""
        </table>
      """)

      module_details = [(count_deps(self.soong.deps, m, []),
                         -count_deps(self.soong.reverse_deps, m, []), m)
                 for m in modules]
      module_details.sort()
      module_details = [m[2] for m in module_details]
      print("""
        <table class="ModuleDetails">""")
      print("<tr>")
      print("  <th>Module Name</th>")
      print("  <th>Issues</th>")
      print("  <th colspan='2'>Blocked By</th>")
      print("  <th colspan='2'>Blocking</th>")
      print("</tr>")
      altRow = True
      for module in module_details:
        analyses = set()
        for filename in self.soong.makefiles[module]:
          makefile = summary.makefiles.get(filename)
          if makefile:
            for analyzer, analysis in makefile.analyses.items():
              if analysis:
                analyses.add(analyzer.title)

        altRow = not altRow
        print("<tr class='%s'>" % ("Alt" if altRow else "",))
        print("  <td><a name='module_%s'></a>%s</td>" % (module, module))
        print("  <td class='AnalysisCol'>%s</td>" % " ".join(["<span class='Analysis'>%s</span>" % title
            for title in analyses]))
        print("  <td>%s</td>" % count_deps(self.soong.deps, module, []))
        print("  <td>%s</td>" % format_module_list(self.soong.deps.get(module, [])))
        print("  <td>%s</td>" % count_deps(self.soong.reverse_deps, module, []))
        print("  <td>%s</td>" % format_module_list(self.soong.reverse_deps.get(module, [])))
        print("</tr>")
      print("""</table>""")

    print_analysis_header("summary", "Overall Summary")

    modules = [module for installed, module in self.soong.installed.items()]
    self.print_analysis_row(overall_summary, modules,
                         "All Makefiles", "TotalRow",
                         set(itertools.chain.from_iterable(overall_summary.directories.values())))
    print("""
        </table>
    """)

    print("""
      <script type="text/javascript">
      function close_details() {
        document.getElementById('details').style.display = 'none';
      }

      class LineMatch {
        constructor(lineno, text) {
          this.lineno = lineno;
          this.text = text;
        }
      }

      class Analysis {
        constructor(filename, modules, line_matches) {
          this.filename = filename;
          this.modules = modules;
          this.line_matches = line_matches;
        }
      }

      class Module {
        constructor(deps) {
          this.deps = deps;
        }
      }

      function make_module_link(module) {
        var a = document.createElement('a');
        a.className = 'ModuleLink';
        a.innerText = module;
        a.href = '#module_' + module;
        return a;
      }

      function update_details(id) {
        document.getElementById('details').style.display = 'block';

        var analyses = ANALYSIS[id];

        var details = document.getElementById("details_data");
        while (details.firstChild) {
            details.removeChild(details.firstChild);
        }

        for (var i=0; i<analyses.length; i++) {
          var analysis = analyses[i];

          var makefileDiv = document.createElement('div');
          makefileDiv.className = 'Makefile';
          details.appendChild(makefileDiv);

          var fileA = document.createElement('a');
          makefileDiv.appendChild(fileA);
          fileA.className = 'CsLink';
          fileA.href = '%(codesearch)s' + analysis.filename;
          fileA.innerText = analysis.filename;
          fileA.target = "_blank";

          if (analysis.modules.length > 0) {
            var moduleTable = document.createElement('table');
            details.appendChild(moduleTable);

            for (var j=0; j<analysis.modules.length; j++) {
              var moduleRow = document.createElement('tr');
              moduleTable.appendChild(moduleRow);

              var moduleNameCell = document.createElement('td');
              moduleRow.appendChild(moduleNameCell);
              moduleNameCell.className = 'ModuleName';
              moduleNameCell.appendChild(make_module_link(analysis.modules[j]));

              var moduleData = MODULE_DATA[analysis.modules[j]];
              console.log(moduleData);

              var depCell = document.createElement('td');
              moduleRow.appendChild(depCell);

              if (moduleData.deps.length == 0) {
                depCell.className = 'ModuleDeps Unblocked';
                depCell.innerText = 'UNBLOCKED';
              } else {
                depCell.className = 'ModuleDeps Blocked';

                for (var k=0; k<moduleData.deps.length; k++) {
                  depCell.appendChild(make_module_link(moduleData.deps[k]));
                  depCell.appendChild(document.createElement('br'));
                }
              }
            }
          }

          if (analysis.line_matches.length > 0) {
            var lineTable = document.createElement('table');
            details.appendChild(lineTable);

            for (var j=0; j<analysis.line_matches.length; j++) {
              var line_match = analysis.line_matches[j];

              var lineRow = document.createElement('tr');
              lineTable.appendChild(lineRow);

              var linenoCell = document.createElement('td');
              lineRow.appendChild(linenoCell);
              linenoCell.className = 'LineNo';

              var linenoA = document.createElement('a');
              linenoCell.appendChild(linenoA);
              linenoA.className = 'CsLink';
              linenoA.href = '%(codesearch)s' + analysis.filename
                  + ';l=' + line_match.lineno;
              linenoA.innerText = line_match.lineno;
              linenoA.target = "_blank";

              var textCell = document.createElement('td');
              lineRow.appendChild(textCell);
              textCell.className = 'LineText';
              textCell.innerText = line_match.text;
            }
          }
        }
      }

      var ANALYSIS = [
      """ % {
          "codesearch": self.args.codesearch,
      })
    for entry, mods in self.annotations.entries:
      print("  [")
      for analysis in entry:
        print("    new Analysis('%(filename)s', %(modules)s, [%(line_matches)s])," % {
          "filename": analysis.filename,
          #"modules": json.dumps([m for m in mods if m in filename in self.soong.makefiles[m]]),
          "modules": json.dumps(
              [m for m in self.soong.reverse_makefiles[analysis.filename] if m in mods]),
          "line_matches": ", ".join([
              "new LineMatch(%d, %s)" % (lineno, json.dumps(text))
              for lineno, text in analysis.line_matches]),
        })
      print("  ],")
    print("""
      ];
      var MODULE_DATA = {
    """)
    for module in self.soong.modules:
      print("      '%(name)s': new Module(%(deps)s)," % {
        "name": module,
        "deps": json.dumps(self.soong.deps[module]),
      })
    print("""
      };
      </script>

    """)

    print("""
        </div> <!-- id=tables -->
        <div id="details">
          <div style="text-align: right;">
            <a href="javascript:close_details();">
              <svg xmlns="http://www.w3.org/2000/svg" height="24" viewBox="0 0 24 24" width="24"><path d="M0 0h24v24H0z" fill="none"/><path d="M19 6.41L17.59 5 12 10.59 6.41 5 5 6.41 10.59 12 5 17.59 6.41 19 12 13.41 17.59 19 19 17.59 13.41 12z"/></svg>
            </a>
          </div>
          <div id="details_data"></div>
        </div>
      </body>
    </html>
    """)

  def traverse_ready_makefiles(self, summary, makefiles):
    return [Analysis(makefile.filename, []) for makefile in makefiles
        if clean_and_only_blocked_by_clean(self.soong, self.all_makefiles, makefile)]

  def print_analysis_row(self, summary, modules, rowtitle, rowclass, makefiles):
    all_makefiles = [Analysis(makefile.filename, []) for makefile in makefiles]
    clean_makefiles = [Analysis(makefile.filename, []) for makefile in makefiles
        if is_clean(makefile)]
    easy_makefiles = self.traverse_ready_makefiles(summary, makefiles)
    unblocked_clean_makefiles = [Analysis(makefile.filename, []) for makefile in makefiles
        if (self.soong.contains_unblocked_modules(makefile.filename)
            and is_clean(makefile))]
    unblocked_makefiles = [Analysis(makefile.filename, []) for makefile in makefiles
        if self.soong.contains_unblocked_modules(makefile.filename)]
    blocked_makefiles = [Analysis(makefile.filename, []) for makefile in makefiles
        if self.soong.contains_blocked_modules(makefile.filename)]

    print("""
      <tr class="%(rowclass)s">
        <td class="RowTitle">%(rowtitle)s</td>
        <td class="Count">%(makefiles)s</td>
        <td class="Count">%(easy)s</td>
        <td class="Count">%(unblocked_clean)s</td>
        <td class="Count">%(unblocked)s</td>
        <td class="Count">%(blocked)s</td>
        <td class="Count">%(clean)s</td>
    """ % {
      "rowclass": rowclass,
      "rowtitle": rowtitle,
      "makefiles": self.make_annotation_link(all_makefiles, modules),
      "unblocked": self.make_annotation_link(unblocked_makefiles, modules),
      "blocked": self.make_annotation_link(blocked_makefiles, modules),
      "clean": self.make_annotation_link(clean_makefiles, modules),
      "unblocked_clean": self.make_annotation_link(unblocked_clean_makefiles, modules),
      "easy": self.make_annotation_link(easy_makefiles, modules),
    })

    for analyzer in ANALYZERS:
      analyses = [m.analyses.get(analyzer) for m in makefiles if m.analyses.get(analyzer)]
      print("""<td class="Count">%s</td>"""
          % self.make_annotation_link(analyses, modules))

    print("      </tr>")

  def make_annotation_link(self, analysis, modules):
    if analysis:
      return "<a href='javascript:update_details(%d)'>%s</a>" % (
        self.annotations.Add(analysis, modules),
        len(analysis)
      )
    else:
      return "";

class CsvProcessor(object):
  def __init__(self, args, soong, all_makefiles):
    self.args = args
    self.soong = soong
    self.all_makefiles = all_makefiles

  def execute(self):
    csvout = csv.writer(sys.stdout)

    # Title row
    row = ["Filename", "Module", "Partitions", "Easy", "Unblocked Clean", "Unblocked",
           "Blocked", "Clean"]
    for analyzer in ANALYZERS:
      row.append(analyzer.title)
    csvout.writerow(row)

    # Makefile & module data
    for filename in sorted(self.all_makefiles.keys()):
      makefile = self.all_makefiles[filename]
      for module in self.soong.reverse_makefiles[filename]:
        row = [filename, module]
        # Partitions
        row.append(";".join(sorted(set([get_partition_from_installed(HOST_OUT_ROOT, PRODUCT_OUT,
                                         installed)
                                        for installed
                                        in self.soong.reverse_installed.get(module, [])]))))
        # Easy
        row.append(1
            if clean_and_only_blocked_by_clean(self.soong, self.all_makefiles, makefile)
            else "")
        # Unblocked Clean
        row.append(1
            if (self.soong.contains_unblocked_modules(makefile.filename) and is_clean(makefile))
            else "")
        # Unblocked
        row.append(1 if self.soong.contains_unblocked_modules(makefile.filename) else "")
        # Blocked
        row.append(1 if self.soong.contains_blocked_modules(makefile.filename) else "")
        # Clean
        row.append(1 if is_clean(makefile) else "")
        # Analysis
        for analyzer in ANALYZERS:
          row.append(1 if makefile.analyses.get(analyzer) else "")
        # Write results
        csvout.writerow(row)

if __name__ == "__main__":
  main()

