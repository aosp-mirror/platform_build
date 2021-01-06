#!/bin/bash

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
-t target...            targets
-m target:installed...  map dependent targets to their installed names
-is_container           preserved dependent target name when given
-o outfile              output file
"

# Global flag variables
license_kinds=
license_conditions=
license_package_name=
license_notice=
license_deps=
targets=
installmap=
is_container=false
ofile=


# Global variables
declare -A depfiles
effective_conditions=
declare -A depModules

# work around bug where "${#array[@]}" traps if never set
depfiles["x"]=808      # set an arbitrary index
unset depfiles["x"]    # delete it to make depfiles empty again
depModules["x"]=808    # set an arbitrary index
unset depModules["x"]  # delete it to make depModules empty again


# Exits with a message.
#
# When the exit status is 2, assumes a usage error and outputs the usage message
# to stderr before outputting the specific error message to stderr.
#
# Parameters:
#   Optional numeric exit status (defaults to 2, i.e. a usage error.)
#   Remaining args treated as an error message sent to stderr.
function die() {
  local status=2
  case "${1:-}" in *[^0-9]*) ;; *) status="$1"; shift ;; esac
  case "${status}" in 2) echo "${USAGE}" >&2; echo >&2 ;; esac
  if [ -n "$*" ]; then
    echo -e "$*\n" >&2
  fi
  exit $status
}


# Sets the flag variables based on the command-line.
#
# invoke with: process_args "$@"
function process_args() {
  local curr_flag=
  local name
  local val
  while [ "$#" -gt '0' ]; do
    case "${1}" in
      -h)
        echo "${USAGE}"
        exit 0
        ;;
      -k)
        curr_flag=kind
        ;;
      -c)
        curr_flag=condition
        ;;
      -p)
        curr_flag=package
        ;;
      -n)
        curr_flag=notice
        ;;
      -d)
        curr_flag=dependency
        ;;
      -t)
        curr_flag=target
        ;;
      -m)
        curr_flag=installmap
        ;;
      -o)
        curr_flag=ofile
        ;;
      -is_container)
        curr_flag=
        is_container=true
        ;;
      -*)
        die "Unknown flag: \"${1}\""
        ;;
      *)
        case "${curr_flag}" in
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
          target)
            targets="${targets}${targets:+ }${1}"
            ;;
          installmap)
            installmap="${installmap}${installmap:+ }${1}"
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

# Reads a license metadata file from stdin, and outputs the named dependencies.
#
# No parameters.
function extract_deps() {
  awk '$1 == "dep_name:" { sub(/^"/, "", $2); sub(/"$/, "", $2); print $2; }'
}

# Populates the `depfiles` associative array mapping dependencies to license
# metadata content.
#
# Starting with the dependencies enumerated in `license_deps`, calculates the
# transitive closure of all dependencies mapping the name of each license
# metadata file to its content.
#
# Dependency names ending in `.meta_module` indirectly reference license
# metadata with 1 license metadata filename per line.
#
# No parameters; no output.
function read_deps() {
  local newdeps=$(
    for d in ${license_deps}; do
      case "${d}" in
        *.meta_module) cat "${d}" ;;
        *) echo "${d}" ;;
      esac
    done | sort -u
  )
  local alldeps=
  local deps=
  local content=
  local mod=
  local dep=
  while [ "${#newdeps}" -gt '0' ]; do
    deps="${newdeps}"
    newdeps=
    for dep in ${deps}; do
      content=$(cat ${dep})
      depfiles["${dep}"]="${content}"
      alldeps="${alldeps}${alldeps:+ }"$(echo "${content}" | extract_deps)
    done
    alldeps=$(for d in ${alldeps}; do echo "${d}"; done | sort -u)
    for d in ${alldeps}; do
      deps=$(
          case "${d}" in
            *.meta_module) cat"${d}" ;;
            *) echo "${d}" ;;
          esac
      )
      for mod in ${deps}; do
        if [ -z "${depfiles[${mod}]+isset}" ]; then
          newdeps="${newdeps}${newdeps:+ }${mod}"
        fi
      done
    done
    alldeps=
  done
}

# Returns the effective license conditions for the current license metadata.
#
# If a module is restricted or links in a restricted module, the effective
# license has a restricted condition.
function calculate_effective_conditions() {
  local conditions="${license_conditions}"
  local condition
  case "${license_conditions}" in
    *restricted*) : do nothing ;;
    *)
       for d in "${!depfiles[@]}"; do
         condition=$(
             echo "${depfiles[${d}]}" | \
                 awk '$1 == "effective_condition:" {
                   $1 = ""
                   print
                 }' \
         )
         case "${condition}" in
           *restricted*)
             conditions="${conditions}${conditions:+ }restricted"
             break
             ;;
         esac
       done
     ;;
  esac
  echo "${conditions}"
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
  echo 'license_package_name: "'${license_package_name}'"'
  for kind in ${license_kinds}; do
    echo 'license_kind: "'${kind}'"'
  done
  for condition in ${license_conditions}; do
    echo 'license_condition: "'${condition}'"'
  done
  for f in ${license_notice}; do
    echo 'license_text: "'${f}'"'
  done
  echo "is_container: ${is_container}"
  for t in ${targets}; do
    echo 'target: "'${t}'"'
  done
  for m in ${installmap}; do
    echo 'install_map: "'${m}'"'
  done
) >>"${ofile}"
read_deps
for dep in "${!depfiles[@]}"; do
  m=$(expr "${dep}" : '^.*[/]\([^/]*\)[.]meta_lic$')
  depModules["${m}"]=true
done
effective_conditions=$(calculate_effective_conditions)
for condition in ${effective_conditions}; do
  echo 'effective_condition: "'${condition}'"'
done >>"${ofile}"
for dep in "${!depfiles[@]}"; do
  echo 'dep {'
  echo "${depfiles[${dep}]}" | \
    awk -v name="${dep}" '
      function strip_type() {
        $1 = ""
        sub(/^\s*/, "")
      }
      BEGIN {
        print "  dep_name: " name
      }
      $1 == "license_package_name:" {
        strip_type()
        print "  dep_package_name: "$0
      }
      $1 == "dep_name:" {
        print "  dep_sub_dep: "$2
      }
      $1 == "license_kind:" {
        print "  dep_license_kind: "$2
      }
      $1 == "license_condition:" {
        print "  dep_license_condition: "$2
      }
      $1 == "is_container:" {
        print "  dep_is_container: "$2
      }
      $1 == "license_text:" {
        strip_type()
        print "  dep_license_text: "$0
      }
      $1 == "target:" {
        print "  dep_target: "$2
      }
      $1 == "install_map:" {
        print "  dep_install_map: "$2
      }
  '
  # The restricted license kind is contagious to all linked dependencies.
  dep_conditions=$(echo $(
      echo "${depfiles[${dep}]}" | awk '
        $1 == "effective_condition:" {
          $1 = ""
          sub(/^\s*/, "")
          gsub(/"/, "")
          print
        }
      '
  ))
  for condition in ${dep_conditions}; do
    echo '  dep_effective_condition: "'${condition}'"'
  done
  if ! ${is_container}; then
    case "${dep_conditions}" in
      *restricted*) : already restricted -- nothing to inherit ;;
      *)
        case "${effective_conditions}" in
          *restricted*)
            # "contagious" restricted infects everything linked to restricted
            echo '  dep_effective_condition: "restricted"'
            ;;
        esac
        ;;
    esac
  fi
  echo '}'
done >>"${ofile}"
