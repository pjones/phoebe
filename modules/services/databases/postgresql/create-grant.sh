#!/bin/bash

################################################################################
# Grant a user specific rights to a database.
set -e

################################################################################
option_user=""
option_database=""
option_access="r"

################################################################################
usage () {
cat <<EOF
Usage: create-grant.sh [options]

  -a LEVEL Access level (r, w, or rw)
  -d NAME  Database name to grant access to
  -h       This message
  -u USER  The user to grant access to
EOF
}

################################################################################
verify_access_level() {
  local level=$1

  case $level in
    r|w|rw)
      echo "$level"
      ;;

    *)
      >&2 echo "ERROR: invalid access level: $level"
      exit 1
  esac
}

################################################################################
while getopts "a:d:hu:" o; do
  case "${o}" in
    a) option_access=$(verify_access_level "$OPTARG")
       ;;

    d) option_database=$OPTARG
       ;;

    h) usage
       exit
       ;;

    u) option_user=$OPTARG
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
echo_grants() {
  local r_list="SELECT"
  local w_list="INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER"

  # Needed to resolve ambiguous role memberships.
  echo "SET ROLE @superuser@;"

  # Start by removing all access then granting the ability to connect:
  echo "REVOKE ALL PRIVILEGES ON DATABASE $option_database FROM $option_user;"
  echo "GRANT CONNECT ON DATABASE $option_database TO $option_user;"

  # Basic options:
  echo "GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA public TO $option_user;"
  echo "ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL PRIVILEGES ON FUNCTIONS TO $option_user;"

  if [ "$option_access" = "r" ] || [ "$option_access" = "rw" ]; then
    echo "GRANT USAGE ON SCHEMA public TO $option_user;"

    echo "GRANT $r_list ON ALL TABLES IN SCHEMA public TO $option_user;"
    echo "ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT $r_list ON TABLES TO $option_user;"

    echo "GRANT USAGE,SELECT ON ALL SEQUENCES IN SCHEMA public TO $option_user;"
    echo "ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT USAGE,SELECT ON SEQUENCES TO $option_user;"
  fi

  if [ "$option_access" = "w" ] || [ "$option_access" = "rw" ]; then
    echo "GRANT $w_list ON ALL TABLES IN SCHEMA public TO $option_user;"
    echo "ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT $w_list ON TABLES TO $option_user;"

    echo "GRANT UPDATE ON ALL SEQUENCES IN SCHEMA public TO $option_user;"
    echo "ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT UPDATE ON  SEQUENCES TO $option_user;"
  fi
}

################################################################################
# Let's do it!
sql_file=$(mktemp)
echo_grants > "$sql_file"
chown @superuser@ "$sql_file"
_psql --dbname="$option_database" --file="$sql_file" --single-transaction
rm "$sql_file"
