#!/bin/bash
set -xeuo pipefail

ROOT_DIR="/var/www/html"
MEMCACHED_HOST="${MEMCACHED_HOST:-limesurvey-memcached}"

# PostgreSQL defaults
PGHOST="${PGHOST:-limesurvey-postgresql}"
PGPORT="${PGPORT:-5432}"
PGDATABASE="${PGDATABASE:-limesurvey}"

## No defaults so it crashes when not set
# MSSQL defaults
#DB_HOST="${DB_HOST:-}"
#DB_PORT="${DB_PORT:-1433}"
#DB_NAME="${DB_NAME:-limesurvey}"
#DB_USER="${DB_USER:-sa}"
#DB_PASSWORD="${DB_PASSWORD:-}"

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

print_step "Checking for LimeSurvey installation..."

CONFIG_FILE="$ROOT_DIR/limesurvey/application/config/email.php"

mkdir -p "$ROOT_DIR/limesurvey/tmp/runtime" "$ROOT_DIR/limesurvey/tmp/runtime/assets" "$ROOT_DIR/limesurvey/tmp/runtime/files"
touch "$ROOT_DIR/limesurvey/application/config/security.php"


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