#!/bin/sh

################################################################################
set -e
set -u

################################################################################
if [ $# -ne 1 ]; then
  >&2 echo "ERROR: must give database name."
  exit 1;
fi

################################################################################
# List all databases:
databases() {
  influx -format csv -execute "show databases" | \
    grep -E '^databases,' | sed 's/^databases,//'
}

################################################################################
if ! (databases | grep --fixed-strings --line-regexp --quiet "$1"); then
  influx -execute "create database $1"
fi
