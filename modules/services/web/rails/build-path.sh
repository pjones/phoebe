#!/bin/bash

################################################################################
# Build a PATH variable given a nix-store path.
set -e
set -u

################################################################################
dirs=()

################################################################################
if [ $# -ne 1 ]; then
  >&2 echo "ERROR: missing store path"
  exit 1
fi

################################################################################
function join() {
  local sep=$1; shift
  local IFS="$sep";
  echo "$*";
}

################################################################################
function maybe_add_dir() {
  local path=$1

  if [ -n "$path" ] && [ -d "$path/bin" ]; then
    dirs+=( "$path/bin" )
  fi
}

################################################################################
function main() {
  local path=$1
  path=$(realpath "$path")

  maybe_add_dir "$path"

  for drv in $(nix-store --query --references "$path"); do
    maybe_add_dir "$drv"
  done

  if [ "${#dirs[@]}" -gt 0 ]; then
    echo "export PATH=$(join : "${dirs[@]}"):$PATH"
  else
    echo "export PATH=$PATH"
  fi
}

################################################################################
main "$1"
