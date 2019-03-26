#!/bin/sh
set -e

# Perform all actions as user 'postgres'
export PGUSER="$POSTGRES_USER"

# Add pgRouting Functions to the database
for DB in template_postgis "$POSTGRES_DB"; do
    echo "Loading pgrouting extensions into $DB"
    "${psql[@]}" --dbname="$DB" <<-'EOSQL'
    psql --dbname="$POSTGRES_DB" <<EOSQL
    CREATE EXTENSION IF NOT EXISTS postgis;
    CREATE EXTENSION IF NOT EXISTS pgrouting;
EOSQL
done
