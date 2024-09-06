ARGV=$(getopt --options '' --long dry-run -- "$@")
eval set -- "$ARGV"
while true; do
    case "$1" in
        --dry-run) repo_upload_dry_run_arg="--dry-run"; repo_branch="finalization-dry-run"; shift ;;
        *) break
    esac
done
