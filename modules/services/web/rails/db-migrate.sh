#!/bin/bash

################################################################################
# Migrate a Ruby on Rails database to its latest version (which might
# mean going back in time for a rollback).
set -e
set -u

################################################################################
option_env=${RAILS_ENV:-production}
option_root=$(pwd)

################################################################################
usage () {
cat <<EOF
Usage: db-migrate.sh [options]

  -e NAME Set RAILS_ENV to NAME
  -h      This message
  -r DIR  The root directory of the Rails app
EOF
}

################################################################################
while getopts "he:r:" o; do
  case "${o}" in
    e) option_env=$OPTARG
       ;;

    h) usage
       exit
       ;;

    r) option_root=$OPTARG
       ;;

    *) exit 1
       ;;
  esac
done

shift $((OPTIND-1))

################################################################################
cd "$option_root"
export RAILS_ENV=$option_env

################################################################################
# If this is a new database, load the schema file:
if [ ! -e config/database-loaded.flag ]; then
  rake db:schema:load
  touch config/database-loaded.flag
fi

################################################################################
# Migrate to the most recent migration version:
latest=$(find db/migrate -type f -exec basename '{}' ';' | sort | tail -n 1 | cut -d_ -f1)
rake db:migrate VERSION="$latest"
