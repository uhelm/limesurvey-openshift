#!/bin/bash
set -euo pipefail

ROOT_DIR="/var/www/html"
DOWNLOAD_LOCKFILE="$ROOT_DIR/.limesurvey_downloaded.lock"
RELEASE="${LIMESURVEY_RELEASE:-6.17.0+260421.zip}"

MEMCACHED_HOST="${MEMCACHED_HOST:-limesurvey-memcached}"

# PostgreSQL defaults
PGHOST="${PGHOST:-limesurvey-postgresql}"
PGPORT="${PGPORT:-5432}"
PGDATABASE="${PGDATABASE:-limesurvey}"

# MSSQL defaults
DB_HOST="${DB_HOST:-}"
DB_PORT="${DB_PORT:-1433}"
DB_NAME="${DB_NAME:-limesurvey}"
DB_USER="${DB_USER:-sa}"
DB_PASSWORD="${DB_PASSWORD:-}"

# Determine database type
DB_TYPE="${DB_TYPE:-}"
if [[ -n "$DB_HOST" ]] && [[ "$DB_HOST" == "mssql" || "$DB_HOST" == "localhost" ]]; then
  DB_TYPE="mssql"
elif [[ -n "$PGHOST" ]]; then
  DB_TYPE="pgsql"
  DB_HOST="$PGHOST"
  DB_PORT="$PGPORT"
  DB_NAME="$PGDATABASE"
  DB_USER="${PGUSER:-}"
  DB_PASSWORD="${PGPASSWORD:-}"
else
  DB_TYPE="pgsql"
fi

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
echo "Database Type: $DB_TYPE"
print_step "Loading secrets..."
[[ -f  "/vault/secrets/limesurvey" ]] &&
  source /vault/secrets/limesurvey
[[ -f  "/vault/secrets/mssql" ]] &&
  source /vault/secrets/mssql

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

CONFIG_FILE="$ROOT_DIR/limesurvey/application/config/config.php"

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "Config file not found, creating a new one."
  if [[ "$DB_TYPE" == "mssql" ]]; then
    cp "$ROOT_DIR/limesurvey/application/config/config-sample-sqlsrv.php" "$CONFIG_FILE"
  else
    cp "$ROOT_DIR/limesurvey/application/config/config-sample-pgsql.php" "$CONFIG_FILE"
  fi
fi

# Update DB config block in config.php
CONFIG_START_LINE=$(grep -n "'db' => array(" "$CONFIG_FILE" | cut -d: -f1)
CONFIG_END_LINE=$(grep -n " )," "$CONFIG_FILE" | cut -d: -f1 | head -n 1)

if [[ "$DB_TYPE" == "mssql" ]]; then
  CONNECTION_STRING="sqlsrv:Server=${DB_HOST},${DB_PORT};Database=${DB_NAME};TrustServerCertificate=True"
  sed -i "${CONFIG_START_LINE},${CONFIG_END_LINE}c \
        'db' => array(\n\
          'connectionString' => '${CONNECTION_STRING}',\n\
          'emulatePrepare' => true,\n\
          'username' => getenv('DB_USER'),\n\
          'password' => getenv('DB_PASSWORD'),\n\
          'charset' => 'utf8',\n\
          'tablePrefix' => '',\n\
          'initSQLs'=>array('SET DATEFORMAT ymd;', 'SET QUOTED_IDENTIFIER ON;')),\n\
        'cache'=>array(\n\
          'class' => 'CMemCache',\n\
          'useMemcached' => true,\n\
          'servers' => array(array(\n\
            'host' => '${MEMCACHED_HOST}',\n\
            'port' => 11211,\n\
            'weight' => 1))),\n\
        # logs to /var/www/html/limesurvey/tmp/runtime/application.log
        'log' => array(
          'routes' => array(
            'filerror' => array(
              'class' => 'CFileLogRoute',
              'levels' => 'warning, error',),))
        )," "$CONFIG_FILE"

else
  sed -i "${CONFIG_START_LINE},${CONFIG_END_LINE}c \
        'db' => array(\n\
          'connectionString' => 'pgsql:host=${DB_HOST};port=${DB_PORT};dbname=${DB_NAME};user=${DB_USER};password=${DB_PASSWORD}',\n\
          'emulatePrepare' => true,\n\
          'username' => '${DB_USER}',\n\
          'password' => '${DB_PASSWORD}',\n\
          'charset' => 'utf8',\n\
          'tablePrefix' => '',),\n\
        'cache'=>array(\n\
          'class' => 'CMemCache',\n\
          'usememcached' => true,\n\
          'servers' => array(\n\
              'host' => 'memcached',\n\
              'port' => 11211,\n\
              'weight' => 1),\n\
        )," "$CONFIG_FILE"
fi
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
      )\
" "$CONFIG_FILE"
print_step "General configuration updated in $CONFIG_FILE."

CONFIG_FILE="$ROOT_DIR/limesurvey/application/config/email.php"

ADMIN_USER="${ADMIN_USER:-admin}"
ADMIN_FULLNAME="${ADMIN_FULLNAME:-Administrator}"
ADMIN_EMAIL="${ADMIN_EMAIL:-admin@example.com}"

sed -i "s|^\(\$config\['siteadminemail'\]\s*=\s*\).*|\1'$ADMIN_EMAIL';|" "$CONFIG_FILE"
sed -i "s|^\(\$config\['siteadminbounce'\]\s*=\s*\).*|\1'$ADMIN_EMAIL';|" "$CONFIG_FILE"
sed -i "s|^\(\$config\['siteadminname'\]\s*=\s*\).*|\1'$ADMIN_FULLNAME';|" "$CONFIG_FILE"

print_step "Email configuration updated in $CONFIG_FILE."

print_step "Ensuring database tables are present..."

# Check if database tables exist
TABLES_EXIST=false
if [[ "$DB_TYPE" == "mssql" ]]; then
  # Use PHP to check MSSQL tables (since sqlcmd may not be available)
  TABLES_EXIST=$(php -r "
    try {
      \$pdo = new PDO('sqlsrv:Server=${DB_HOST},${DB_PORT};TrustServerCertificate=True;Database=${DB_NAME}', '${DB_USER}', '${DB_PASSWORD}');
      \$result = \$pdo->query(\"SELECT COUNT(*) FROM information_schema.tables WHERE table_type='BASE TABLE'\");
      \$count = \$result->fetchColumn();
      echo (\$count > 0) ? 'true' : 'false';
    } catch (Exception \$e) {
      echo "\$e";
      echo 'false';
    }
  " || echo 'false')
  echo $TABLES_EXIST
else
  # Use psql for PostgreSQL
  table_list_result=$(psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "\dt" 2>/dev/null || echo "")
  table_list_has_results=$(echo "$table_list_result" | grep -v 'No relations found.' || echo "")
  TABLES_EXIST=$([ -n "$table_list_has_results" ] && echo 'true' || echo 'false')
fi

if [[ "$TABLES_EXIST" != "true" ]]; then
  echo "Setting up LimeSurvey database..."
  cd "$ROOT_DIR/limesurvey/application/commands"

  if [[ -z "${ADMIN_PASSWORD:-}" ]]; then
    echo "ADMIN_PASSWORD is not set, generating a random password."
    ADMIN_PASSWORD=$(openssl rand -base64 12)
    echo "Generated ADMIN_PASSWORD: $ADMIN_PASSWORD"
  fi

  echo "Completing LimeSurvey installation..."
  php "$ROOT_DIR/limesurvey/application/commands/console.php" install "$ADMIN_USER" "$ADMIN_PASSWORD" "$ADMIN_FULLNAME" "$ADMIN_EMAIL"
else
  echo "Database appears to be initialized."
fi

print_step "Initial setup tasks completed."
echo "LimeSurvey is ready to launch."
echo "=== Exiting init script ==="
exit 0