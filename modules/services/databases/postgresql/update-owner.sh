#!/bin/bash

################################################################################
# Update object ownership.
set -e

################################################################################
option_owner=""
option_database=""
option_schema="public"

################################################################################
usage () {
cat <<EOF
Usage: update-owner.sh [options]

  -d NAME Database name to alter
  -h      This message
  -o NAME Object owner

EOF
}

################################################################################
while getopts "d:ho:" o; do
  case "${o}" in
    d) option_database=$OPTARG
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
set_database_owner_sql() {
  echo "ALTER DATABASE $option_database OWNER TO $option_owner;"
}

################################################################################
# Send STDIN to psql and output just the row data.
list_selected_rows() {
  _psql --tuples-only --no-align --dbname="$option_database"
}

################################################################################
list_tables() {
  local schema=$1

  echo "SELECT tablename FROM pg_tables WHERE schemaname = '${schema}';" | \
    list_selected_rows
}

################################################################################
list_sequences() {
  local schema=$1

  echo "SELECT sequence_name FROM information_schema.sequences WHERE sequence_schema = '${schema}';" | \
    list_selected_rows
}

################################################################################
list_views() {
  local schema=$1

  echo "SELECT table_name FROM information_schema.views WHERE table_schema = '${schema}';" | \
    list_selected_rows
}

################################################################################
update_object_owner() {
  local object_type=$1
  local object=$2

  echo "ALTER $object_type \"$object\" OWNER TO $option_owner;"
}

################################################################################
sql_file=$(mktemp)
set_database_owner_sql > "$sql_file"

for t in $(list_tables "$option_schema"); do
  update_object_owner "TABLE" "$t" >> "$sql_file"
done

for s in $(list_sequences "$option_schema"); do
  update_object_owner "SEQUENCE" "$s" >> "$sql_file"
done

for v in $(list_views "$option_schema"); do
  update_object_owner "VIEW" "$v" >> "$sql_file"
done

chown @superuser@ "$sql_file"
_psql --dbname="$option_database" --file="$sql_file" --single-transaction
rm "$sql_file"
