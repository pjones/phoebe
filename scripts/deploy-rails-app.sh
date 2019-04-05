#!/bin/sh

################################################################################
# Example script to deploy a rails application:
set -e
set -u

################################################################################
option_base="/var/lib/rails"
option_app_name=""
option_host=""

################################################################################
usage() {
  cat <<EOF
Usage: $(basename "$0") -n <name> -t <host> [options]

  -h      This message
  -n NAME Application name
  -p PATH Base path of Rails application (default: $option_base)
  -t HOST SSH host to deploy to (e.g., root@example.com)
EOF
}

################################################################################
while getopts "hn:p:t:" o; do
  case "${o}" in
    h) usage
       exit
       ;;

    n) option_app_name=$OPTARG
       ;;

    p) option_base=$OPTARG
       ;;

    t) option_host=$OPTARG
       ;;

    *) exit 1
       ;;
  esac
done

shift $((OPTIND-1))

################################################################################
if [ ! -e default.nix ]; then
  >&2 echo "ERROR: Run this from a directory that has a default.nix file"
  exit 1
fi

################################################################################
if [ -z "$option_app_name" ]; then
  >&2 echo "ERROR: You must use the -n option to name the application"
  exit 1
fi

################################################################################
if [ -z "$option_host" ]; then
  >&2 echo "ERROR: You must use the -t option to specify the host"
  exit 1
fi

################################################################################
if [ $# -ne 0 ]; then
  >&2 echo "ERROR: invalid options given: $*"
  exit 1
fi

################################################################################
echo "==> Building application"
path=$(nix-build --quiet --no-out-link)

echo "==> Uploading application to $option_host"
nix-copy-closure --use-substitutes --to "$option_host" "$path"

# Create the GC root:
echo "==> Installing and activating application"
ssh "$option_host" \
    nix-store --add-root "$option_base/$option_app_name/package" \
              --indirect --realize --quiet "$path"

# Restart the application:
echo "==> Restarting application"
ssh "$option_host" systemctl restart rails-"$option_app_name"-'\*'
