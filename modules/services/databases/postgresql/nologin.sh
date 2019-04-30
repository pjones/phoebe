#!/bin/bash

################################################################################
# Generate SQL that locks out all users (except the superuser).
set -e
set -u

################################################################################
_psql() {
  @sudo@ -u @superuser@ -H psql "$@"
}

################################################################################
accounts() {
  echo "SELECT rolname FROM pg_catalog.pg_roles;" | \
    _psql --tuples-only postgres | \
    sed 's/^[[:space:]]*//' | \
    grep --fixed-strings --invert-match --line-regexp '@superuser@' | \
    grep --extended-regexp --invert-match '^pg_'
}

################################################################################
for name in $(accounts); do
  if [ -n "$name" ]; then
    echo "ALTER ROLE $name NOLOGIN;"
  fi
done
