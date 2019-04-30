#!/bin/bash

################################################################################
# Create a database if it's missing.
set -e

################################################################################
option_database=""
option_owner="@superuser@"
option_extensions=""

################################################################################
usage () {
cat <<EOF
Usage: create-db.sh [options]

  -d NAME Database name to create
  -e LIST Space-separated list of extensions to enable
  -h      This message
  -o USER The owner of the new database.
EOF
}

################################################################################
while getopts "d:e:ho:" o; do
  case "${o}" in
    d) option_database=$OPTARG
       ;;

    e) option_extensions=$OPTARG
       ;;

    h) usage
       exit
       ;;

    o) option_owner=$OPTARG
       ;;

    *) exit 1
       ;;
  esac
done

shift $((OPTIND-1))

################################################################################
_psql() {
  @sudo@ -u @superuser@ -H psql "$@"
}

################################################################################
create_database() {
  has_db=$(_psql -tAl | cut -d'|' -f1 | grep -cF "$option_database" || :)

  if [ "$has_db" -eq 0 ]; then
    @sudo@ -u @superuser@ -H \
     createdb --owner "$option_owner" "$option_database"
  fi
}

################################################################################
enable_extensions() {
  if [ -n "$option_extensions" ]; then
    for ext in $option_extensions; do
      _psql "$option_database" -c "CREATE EXTENSION IF NOT EXISTS $ext"
    done
  fi
}

################################################################################
if [ -z "$option_database" ]; then
  >&2 echo "ERROR: must give -d"
  exit 1;
fi

################################################################################
create_database
enable_extensions
