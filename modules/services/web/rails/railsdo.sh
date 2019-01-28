#!/bin/sh

################################################################################
set -e
set -u

################################################################################
usage() {
  cat <<EOF
Usage: $(basename "$0") name command [option...]

Run a command while logged in as the Rails user NAME.

Example:

  railsdo myapp rake routes

EOF
}

################################################################################
if [ $# -lt 2 ] || [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  usage
  exit 1
fi

################################################################################
name=$1; shift

################################################################################
if ! id -u "rails-$name" > /dev/null 2>&1; then
  >&2 echo "ERROR: $name doesn't appear to be a valid rails application"
  exit 1
fi

################################################################################
sudo --user="rails-$name" --login sh -c "cd app && $*"
