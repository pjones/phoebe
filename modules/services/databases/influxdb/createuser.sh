#!/bin/sh

################################################################################
set -e
set -u

################################################################################
if [ $# -ne 3 ]; then
  >&2 echo "ERROR: Usage: createuser.sh name file isadmin"
  exit 1
fi

################################################################################
name=$(echo "$1" | tr --complement --delete "a-zA-Z0-9_-")
pass=$(head -n 1 "$2" | tr --delete "'")
isadmin=$3

################################################################################
# List all users:
users() {
  influx -format csv -execute "show users" | \
    grep -Ev '^user,admin$' | \
    sed 's/^/,/' # Allow searches to be anchored.
}

################################################################################
find_user() {
  user=$1

  users | \
    grep --fixed-strings --ignore-case ",${user}," | \
    head -n 1 | \
    sed 's/^,//'
}

################################################################################
match=$(find_user "$name")

if [ -z "${match}" ]; then
  if [ "$isadmin" -eq 1 ]; then
    # Need to create admin user.  Needs to be a separate branch
    # because this is the only query allowed when authentication is
    # enabled but there are no users yet.
    match="${name},true"
    influx -execute "CREATE USER ${name} WITH PASSWORD '${pass}' WITH ALL PRIVILEGES"
  else
    # Need to create user a regular user.
    match="${name},false"
    influx -execute "CREATE USER ${name} WITH PASSWORD '${pass}'"
  fi
else
 # Need to update password:
  influx -execute "SET PASSWORD FOR \"${name}\" = '${pass}'"
fi

# Double check the access level:
if [ "$isadmin" -eq 1 ] && [ "$match" = "${name},false" ]; then
  influx -execute "GRANT ALL PRIVILEGES TO \"${name}\""
elif [ "$isadmin" -eq 0 ] && [ "$match" = "${name},true" ]; then
  influx -execute "REVOKE ALL PRIVILEGES FROM \"${name}\""
fi
