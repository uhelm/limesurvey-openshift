#!/bin/bash
set -euo pipefail

ROOT_DIR="/var/www/html"
DOWNLOAD_LOCKFILE="$ROOT_DIR/.limesurvey_downloaded.lock"
RELEASE="${LIMESURVEY_RELEASE:-6.15.5+250724.zip}"
PGHOST="${PGHOST:-limesurvey-postgresql}"
PGPORT="${PGPORT:-5432}"
PGDATABASE="${PGDATABASE:-limesurvey}"

CURRENT_STEP=1
TOTAL_STEPS=$(grep -c '^print_step' "${BASH_SOURCE[0]}")
function print_step {
  local LIGHT="\033[1;32m"
  local RESET="\033[0m"
if [[ -z "$1" ]]; then
    echo -e "${LIGHT}[Step $CURRENT_STEP/$TOTAL_STEPS]${RESET}"
  else
    echo -e "${LIGHT}[Step $CURRENT_STEP/$TOTAL_STEPS]${RESET} $1"
  fi
  CURRENT_STEP=$((CURRENT_STEP + 1))
}

echo "=== Initializing Limesurvey ==="
print_step "Loading secrets..."
source /vault/secrets/postgres
source /vault/secrets/limesurvey


print_step "Checking for LimeSurvey installation..."
if [[ ! -f "$DOWNLOAD_LOCKFILE" ]]; then
  echo "LimeSurvey not found, downloading..."
  rm -rf "$ROOT_DIR/limesurvey"
  curl -L "https://download.limesurvey.org/latest-master/limesurvey${RELEASE}" -o /tmp/limesurvey.zip
  echo "Download completed, extracting... (this may take a moment)"
  unzip -o /tmp/limesurvey.zip -d "$ROOT_DIR" | pv -lf -s "$(unzip -l /tmp/limesurvey.zip | wc -l)" > /dev/null
  echo "Unzip completed, cleaning up..."
  rm -f /tmp/limesurvey.zip
  touch "$DOWNLOAD_LOCKFILE"
  echo "LimeSurvey downloaded and extracted."
else
  echo "LimeSurvey already present, skipping download."
fi


print_step "Waiting for PostgreSQL to be ready..."
until pg_isready -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d "$PGDATABASE" > /dev/null; do
  echo "PostgreSQL is not ready yet, waiting..."
  sleep 5
done
echo "PostgreSQL is accepting connections."

CONFIG_FILE="$ROOT_DIR/limesurvey/application/config/config.php"

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "Config file not found, creating a new one."
  cp "$ROOT_DIR/limesurvey/application/config/config-sample-pgsql.php" "$CONFIG_FILE"
fi

# Update DB config block in config.php
CONFIG_START_LINE=$(grep -n "'db' => array(" "$CONFIG_FILE" | cut -d: -f1)
CONFIG_END_LINE=$(grep -n ")," "$CONFIG_FILE" | cut -d: -f1 | head -n 1)

sed -i "${CONFIG_START_LINE},${CONFIG_END_LINE}c \
      'db' => array(\n\
        'connectionString' => 'pgsql:host=${PGHOST};port=${PGPORT};dbname=${PGDATABASE};user=${PGUSER};password=${PGPASSWORD}',\n\
        'emulatePrepare' => true,\n\
        'username' => '$PGUSER',\n\
        'password' => '$PGPASSWORD',\n\
        'charset' => 'utf8',\n\
        'tablePrefix' => '',\n\
      ),\n\
    " "$CONFIG_FILE"
print_step "Database configuration updated in $CONFIG_FILE."

CONFIG_START_LINE=$(grep -nE "'config' ?=> ?array\(" "$CONFIG_FILE" | cut -d: -f1)
CONFIG_END_LINE=$(grep -nE "\)$" "$CONFIG_FILE" | cut -d: -f1 | tail -n 1)

sed -i "${CONFIG_START_LINE},${CONFIG_END_LINE}c \
      'config' => array(\n\
          'baseUrl' => '/limesurvey',\n\
          'debug' => 0,\n\
          'debugsql' => 0,\n\
          'force_ssl' => true,\n\
          'language' => 'en',\n\
          'sitename' => 'BC Gov Survey',\n\
      )\n\
      " "$CONFIG_FILE"
print_step "General configuration updated in $CONFIG_FILE."

CONFIG_FILE="$ROOT_DIR/limesurvey/application/config/email.php"

sed -i "s|^\(\$config\['siteadminemail'\]\s*=\s*\).*|\1'$ADMIN_EMAIL';|" "$CONFIG_FILE"
sed -i "s|^\(\$config\['siteadminbounce'\]\s*=\s*\).*|\1'$ADMIN_EMAIL';|" "$CONFIG_FILE"
sed -i "s|^\(\$config\['siteadminname'\]\s*=\s*\).*|\1'$ADMIN_FULLNAME';|" "$CONFIG_FILE"

print_step "Email configuration updated in $CONFIG_FILE."

table_list_result=$(psql -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d "$PGDATABASE" -c "\dt")
table_list_has_results=$(echo "$table_list_result" | grep -v 'No relations found.')
print_step "Ensuring database tables are present..."
if [[ -z "$table_list_has_results" ]]; then
  echo "Setting up LimeSurvey database..."
  cd "$ROOT_DIR/limesurvey/application/commands"

  if [[ -z "${ADMIN_PASSWORD:-}" ]]; then
    echo "ADMIN_PASSWORD is not set, generating a random password."
    ADMIN_PASSWORD=$(openssl rand -base64 12)
    echo "Generated ADMIN_PASSWORD: $ADMIN_PASSWORD"
  fi
  ADMIN_USER="${ADMIN_USER:-admin}"
  ADMIN_FULLNAME="${ADMIN_FULLNAME:-Administrator}"
  ADMIN_EMAIL="${ADMIN_EMAIL:-admin@example.com}"

  echo "Completing LimeSurvey installation..."
  php "$ROOT_DIR/limesurvey/application/commands/console.php" install "$ADMIN_USER" "$ADMIN_PASSWORD" "$ADMIN_FULLNAME" "$ADMIN_EMAIL"
else
  echo "Database appears to be initialized; showing existing tables:"
  echo "$table_list_result" | head -n 10
  n_tables=$(echo "$table_list_result" | wc -l)
  if [[ $n_tables -gt 10 ]]; then
    echo " ... And $((n_tables - 10)) more.\n"
  fi
fi

print_step "Initial setup tasks completed."
echo "LimeSurvey is ready to launch."
echo "=== Exiting init script ==="
exit 0