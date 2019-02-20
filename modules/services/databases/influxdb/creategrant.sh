#!/bin/sh

################################################################################
set -e
set -u

################################################################################
if [ $# -ne 3 ]; then
  >&2 echo "Usage: creategrant.sh user database privilege"
  exit 1
fi

################################################################################
name=$(echo "$1" | tr --complement --delete "a-zA-Z0-9_-")
db=$(echo "$2"   | tr --complement --delete "a-zA-Z0-9_-")
priv=$3

################################################################################
privileges() {
  influx -format csv -execute "SHOW GRANTS FOR \"${name}\"" | \
    grep -v "^database,privilege$" | \
    sed 's/^/,/' # Add for anchoring.
}

################################################################################
privilege_for_db() {
  privileges | \
    grep --fixed-strings ",${db}," | \
    head -n 1 | sed -e 's/^,//' -e 's/ .*$//' |  cut -d, -f2
}

################################################################################
match=$(privilege_for_db)

if [ -z "$match" ]; then
  influx -execute "GRANT ${priv} ON \"${db}\" TO \"${name}\""
elif [ "$priv" != "$match" ]; then
  influx -execute "REVOKE ALL ON \"${db}\" FROM \"${name}\""
  influx -execute "GRANT ${priv} ON \"${db}\" TO \"${name}\""
fi
