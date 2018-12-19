#!/bin/bash

################################################################################
set -e

################################################################################
option_username=""
option_password_file=""
option_database=""
option_extensions=""
option_sqlfile="@out@/sql/create-user.sql"

################################################################################
usage () {
cat <<EOF
Usage: create-user.sh [options]

  -d NAME Database name to create for USER
  -e LIST Space-separated list of extensions to enable
  -h      This message
  -p FILE File containing USER's password
  -s FILE The SQL template file (pg-create-user.sql)
  -u USER Username to create
EOF
}

################################################################################
while getopts "d:e:hp:s:u:" o; do
  case "${o}" in
    d) option_database=$OPTARG
       ;;

    e) option_extensions=$OPTARG
       ;;

    h) usage
       exit
       ;;

    p) option_password_file=$OPTARG
       ;;

    s) option_sqlfile=$OPTARG
       ;;

    u) option_username=$OPTARG
       ;;

    *) exit 1
       ;;
  esac
done

shift $((OPTIND-1))

################################################################################
tmp_sql_file=$(mktemp --suffix=.sql --tmpdir new-user.XXXXXXXXX)

cleanup() {
  rm -f "$tmp_sql_file"
}

trap cleanup EXIT

################################################################################
_psql() {
  @sudo@ -u @superuser@ -H psql "$@"
}

################################################################################
mksql() {
  # FIXME: Passwords can't contain single quotes due to this simple logic:
  if head -n 1 "$option_password_file" | grep -q "'"; then
    >&2 echo "ERROR: password for $option_username contains single quote!"
    exit 1
  fi

  password=$(head -n 1 "$option_password_file")

  awk -v 'USERNAME'="$option_username" \
      -v 'PASSWORD'="$password" \
      ' { gsub(/@@USERNAME@@/, USERNAME);
          gsub(/@@PASSWORD@@/, PASSWORD);
          print;
        }
      ' < "$option_sqlfile" > "$tmp_sql_file"

  # Let the database user read the generated file.
  chmod go+r "$tmp_sql_file"
}

################################################################################
create_user() {
  mksql
  _psql -d postgres -f "$tmp_sql_file" > /dev/null
}

################################################################################
create_database() {
  has_db=$(_psql -tAl | cut -d'|' -f1 | grep -cF "$option_database" || :)

  if [ "$has_db" -eq 0 ]; then
    @sudo@ -u @superuser@ -H \
     createdb --owner "$option_username" "$option_database"
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
create_user
create_database
enable_extensions
