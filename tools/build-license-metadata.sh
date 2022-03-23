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
depfiles=" "
effective_conditions=


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
      -t)
        lcurr_flag=target
        ;;
      -m)
        lcurr_flag=installmap
        ;;
      -o)
        lcurr_flag=ofile
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
extract_deps() {
  awk '$1 == "dep_name:" { sub(/^"/, "", $2); sub(/"$/, "", $2); print $2; }'
}

# Populates the depfiles variable identifying dependency files.
#
# Starting with the dependencies enumerated in license_deps, calculates the
# transitive closure of all dependencies.
#
# Dependency names ending in .meta_module indirectly reference license
# metadata with 1 license metadata filename per line.
#
# No parameters; no output.
read_deps() {
  lnewdeps=
  for d in ${license_deps}; do
    case "${d}" in
      *.meta_module)
        lnewdeps="${lnewdeps}${lnewdeps:+ }"$(cat "${d}") ;;
      *)
        lnewdeps="${lnewdeps}${lnewdeps:+ }${d}" ;;
    esac
  done
  lnewdeps=$(echo "${lnewdeps}" | tr ' ' '\n' | sort -u)
  lalldeps=
  ldeps=
  lmod=
  ldep=
  while [ "${#lnewdeps}" -gt '0' ]; do
    ldeps="${lnewdeps}"
    lnewdeps=
    for ldep in ${ldeps}; do
      depfiles="${depfiles}${ldep} "
      lalldeps="${lalldeps}${lalldeps:+ }"$(cat "${ldep}" | extract_deps)
    done
    lalldeps=$(for d in ${lalldeps}; do echo "${d}"; done | sort -u)
    for d in ${lalldeps}; do
      ldeps="${d}"
      case "${d}" in *.meta_module) ldeps=$(cat "${d}") ;; esac
      for lmod in ${ldeps}; do
        if ! expr "${depfiles}" : ".* ${lmod} .*" >/dev/null 2>&1; then
          lnewdeps="${lnewdeps}${lnewdeps:+ }${lmod}"
        fi
      done
    done
    lalldeps=
  done
}

# Returns the effective license conditions for the current license metadata.
#
# If a module is restricted or links in a restricted module, the effective
# license has a restricted condition.
calculate_effective_conditions() {
  lconditions="${license_conditions}"
  case "${license_conditions}" in
    *restricted*) : do nothing ;;
    *)
       for d in ${depfiles}; do
         if cat "${d}" | egrep -q 'effective_condition\s*:.*restricted' ; then
           lconditions="${lconditions}${lconditions:+ }restricted"
           break
         fi
       done
     ;;
  esac
  echo "${lconditions}"
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
effective_conditions=$(calculate_effective_conditions)
for condition in ${effective_conditions}; do
  echo 'effective_condition: "'${condition}'"'
done >>"${ofile}"
for dep in ${depfiles}; do
  echo 'dep {'
  cat "${dep}" | \
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
      cat "${dep}" | awk '
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
