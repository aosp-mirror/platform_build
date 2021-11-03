#!/bin/sh

set -u

ME=$(basename $0)

USAGE="Usage: ${ME} {options}

Builds a license metadata specification and outputs it to stdout or {outfile}.

The available options are:

-k kind...              license kinds
-c condition...         license conditions
-p package...           license package name
-n notice...            license notice file
-d dependency...        license metadata file dependency
-s dependency...        source (input) dependency
-t target...            built targets
-i target...            installed targets
-r root...              root directory of project
-m target:installed...  map dependent targets to their installed names
-mc module_class...     module class
-mt module_type...      module type
-is_container           preserved dependent target name when given
-o outfile              output file
"

# Global flag variables
license_kinds=
license_conditions=
license_package_name=
license_notice=
license_deps=
module_class=
module_type=
source_deps=
targets=
installed=
installmap=
is_container=false
ofile=
roots=

# Global variables
depfiles=" "


# Exits with a message.
#
# When the exit status is 2, assumes a usage error and outputs the usage message
# to stderr before outputting the specific error message to stderr.
#
# Parameters:
#   Optional numeric exit status (defaults to 2, i.e. a usage error.)
#   Remaining args treated as an error message sent to stderr.
die() {
  lstatus=2
  case "${1:-}" in *[^0-9]*) ;; *) lstatus="$1"; shift ;; esac
  case "${lstatus}" in 2) echo "${USAGE}" >&2; echo >&2 ;; esac
  if [ -n "$*" ]; then
    echo -e "$*\n" >&2
  fi
  exit $lstatus
}


# Sets the flag variables based on the command-line.
#
# invoke with: process_args "$@"
process_args() {
  lcurr_flag=
  while [ "$#" -gt '0' ]; do
    case "${1}" in
      -h)
        echo "${USAGE}"
        exit 0
        ;;
      -k)
        lcurr_flag=kind
        ;;
      -c)
        lcurr_flag=condition
        ;;
      -p)
        lcurr_flag=package
        ;;
      -n)
        lcurr_flag=notice
        ;;
      -d)
        lcurr_flag=dependency
        ;;
      -s)
        lcurr_flag=source
        ;;
      -t)
        lcurr_flag=target
        ;;
      -i)
        lcurr_flag=install
        ;;
      -m)
        lcurr_flag=installmap
        ;;
      -mc)
        lcurr_flag=class
        ;;
      -mt)
        lcurr_flag=type
        ;;
      -o)
        lcurr_flag=ofile
        ;;
      -r)
        lcurr_flag=root
        ;;
      -is_container)
        lcurr_flag=
        is_container=true
        ;;
      -*)
        die "Unknown flag: \"${1}\""
        ;;
      *)
        case "${lcurr_flag}" in
          kind)
            license_kinds="${license_kinds}${license_kinds:+ }${1}"
            ;;
          condition)
            license_conditions="${license_conditions}${license_conditions:+ }${1}"
            ;;
          package)
            license_package_name="${license_package_name}${license_package_name:+ }${1}"
            ;;
          notice)
            license_notice="${license_notice}${license_notice:+ }${1}"
            ;;
          dependency)
            license_deps="${license_deps}${license_deps:+ }${1}"
            ;;
          source)
            source_deps="${source_deps}${source_deps:+ }${1}"
            ;;
          target)
            targets="${targets}${targets:+ }${1}"
            ;;
          install)
            installed="${installed}${installed:+ }${1}"
            ;;
          installmap)
            installmap="${installmap}${installmap:+ }${1}"
            ;;
          class)
            module_class="${module_class}${module_class:+ }${1}"
            ;;
          type)
            module_type="${module_type}${module_type:+ }${1}"
            ;;
          root)
            root="${1}"
            while [ -n "${root}" ] && ! [ "${root}" == '.' ] && \
                ! [ "${root}" == '/' ]; \
            do
              if [ -d "${root}/.git" ]; then
                roots="${roots}${roots:+ }${root}"
                break
              fi
              root=$(dirname "${root}")
            done
            ;;
          ofile)
            if [ -n "${ofile}" ]; then
              die "Output file -o appears twice as \"${ofile}\" and \"${1}\""
            fi
            ofile="${1}"
            ;;
          *)
            die "Must precede argument \"${1}\" with type flag."
            ;;
        esac
        ;;
    esac
    shift
  done
}


process_args "$@"

if [ -n "${ofile}" ]; then
  # truncate the output file before appending results
  : >"${ofile}"
else
  ofile=/dev/stdout
fi

# spit out the license metadata file content
(
  echo 'license_package_name: "'"${license_package_name}"'"'
  for t in ${module_type}; do
    echo 'module_type: "'"${t}"'"'
  done
  for c in ${module_class}; do
    echo 'module_class: "'"${c}"'"'
  done
  for r in ${roots}; do
    echo 'root: "'"${r}"'"'
  done
  for kind in ${license_kinds}; do
    echo 'license_kind: "'"${kind}"'"'
  done
  for condition in ${license_conditions}; do
    echo 'license_condition: "'"${condition}"'"'
  done
  for f in ${license_notice}; do
    echo 'license_text: "'"${f}"'"'
  done
  echo "is_container: ${is_container}"
  for t in ${targets}; do
    echo 'built: "'"${t}"'"'
  done
  for i in ${installed}; do
    echo 'installed: "'"${i}"'"'
  done
  for m in ${installmap}; do
    echo 'install_map: "'"${m}"'"'
  done
  for s in ${source_deps}; do
    echo 'source: "'"${s}"'"'
  done
) >>"${ofile}"
depfiles=" $(echo $(echo ${license_deps} | tr ' ' '\n' | sort -u)) "
for dep in ${depfiles}; do
  echo 'dep: "'"${dep}"'"'
done >>"${ofile}"
