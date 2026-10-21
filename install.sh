#!/bin/bash
# Install Asternic Call Center Stats Lite on Issabel.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="${LOG_FILE:-/var/log/asternic-stats-lite-install.log}"
WEB_ROOT="/var/www/html/queue-stats"
PARSELOG_ROOT="/usr/local/parseloglite"
DB_NAME="qstatslite"
DB_USER="qstatsliteuser"
AMI_USER="phpconfig"
AMI_SECRET="php[onfig"
CRON_ENTRY="*/5 * * * * php -q /usr/local/parseloglite/parselog.php convertlocal"

log() {
    mkdir -p "$(dirname "${LOG_FILE}")"
    printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" | tee -a "${LOG_FILE}"
}

fail() {
    log "ERROR: $*"
    exit 1
}

require_command() {
    command -v "$1" >/dev/null 2>&1 || fail "Required command not found: $1"
}

read_issabel_mysql_password() {
    [[ -r /etc/issabel.conf ]] || fail "/etc/issabel.conf was not found"

    local password
    password="$(sed -n 's/^[[:space:]]*mysqlrootpwd[[:space:]]*=[[:space:]]*//p' /etc/issabel.conf | head -n 1)"
    [[ -n "${password}" ]] || fail "mysqlrootpwd was not found in /etc/issabel.conf"
    printf '%s' "${password}"
}

sql_escape() {
    printf '%s' "$1" | sed "s/'/''/g"
}

sed_escape() {
    printf '%s' "$1" | sed 's/[\/&#\\]/\\&/g'
}

configure_database() {
    local db_password="$1"
    local sql_password
    sql_password="$(sql_escape "${db_password}")"

    log "Checking MySQL access"
    mysql -u root -p"${db_password}" -e "SELECT 1" >/dev/null

    log "Creating Asternic database"
    mysqladmin -u root -p"${db_password}" create "${DB_NAME}" 2>/dev/null || \
        mysql -u root -p"${db_password}" -e "SELECT 1 FROM information_schema.SCHEMATA WHERE SCHEMA_NAME='${DB_NAME}'" >/dev/null

    if mysql -u root -p"${db_password}" "${DB_NAME}" -e \
        "SELECT 1 FROM information_schema.TABLES WHERE TABLE_SCHEMA='${DB_NAME}' AND TABLE_NAME='qagent' LIMIT 1" |
        grep -q '^1$'; then
        log "Asternic database schema already exists; preserving existing tables and data"
    else
        log "Importing Asternic database schema"
        mysql -u root -p"${db_password}" "${DB_NAME}" < "${SCRIPT_DIR}/sql/qstats.sql"
    fi

    log "Configuring Asternic database user"
    mysql -u root -p"${db_password}" -e \
        "CREATE USER '${DB_USER}'@'localhost' IDENTIFIED BY '${sql_password}'" 2>/dev/null || \
        mysql -u root -p"${db_password}" -e \
        "ALTER USER '${DB_USER}'@'localhost' IDENTIFIED BY '${sql_password}'"
    mysql -u root -p"${db_password}" -e \
        "GRANT SELECT, INSERT, UPDATE, DELETE ON ${DB_NAME}.* TO '${DB_USER}'@'localhost'"
    mysql -u root -p"${db_password}" -e \
        "ALTER DATABASE ${DB_NAME} CHARACTER SET utf8 COLLATE utf8_unicode_ci"

    local table
    for table in queue_stats qname qevent qagent; do
        mysql -u root -p"${db_password}" -e \
            "ALTER TABLE ${DB_NAME}.${table} CONVERT TO CHARACTER SET utf8 COLLATE utf8_unicode_ci"
    done
}

install_files() {
    log "Installing Asternic web files"
    mkdir -p "${WEB_ROOT}" "${PARSELOG_ROOT}"
    cp -rf "${SCRIPT_DIR}/html/." "${WEB_ROOT}/"
    cp -rf "${SCRIPT_DIR}/parselog/." "${PARSELOG_ROOT}/"
    touch "${WEB_ROOT}/css/voiz-asternic.css" \
        "${WEB_ROOT}/css/vendor/persianDatepicker-default.css" \
        "${WEB_ROOT}/js/jalali.js" \
        "${WEB_ROOT}/js/vendor/persianDatepicker.min.js"

    local escaped_password
    escaped_password="$(sed_escape "$1")"
    sed -i "s#^[[:space:]]*.*dbpass[[:space:]]*=.*#\\\$dbpass = '${escaped_password}';#" \
        "${WEB_ROOT}/config.php" "${PARSELOG_ROOT}/config.php"

    [[ -f "${WEB_ROOT}/config.php" ]] || fail "Asternic web configuration was not installed"
    [[ -f "${PARSELOG_ROOT}/config.php" ]] || fail "Asternic parser configuration was not installed"
}

configure_ami() {
    local manager_conf="/etc/asterisk/manager.conf"
    local custom_conf="/etc/asterisk/manager_custom.conf"

    [[ -d /etc/asterisk ]] || fail "/etc/asterisk was not found"
    touch "${custom_conf}"

    if ! grep -Rqs "^\[${AMI_USER}\][[:space:]]*$" "${manager_conf}" "${custom_conf}" 2>/dev/null; then
        cat >> "${custom_conf}" <<EOF

[${AMI_USER}]
secret=${AMI_SECRET}
deny=0.0.0.0/0.0.0.0
permit=127.0.0.1/255.255.255.0
read=all
write=all
EOF
        log "Added ${AMI_USER} to ${custom_conf}"
    else
        log "AMI user ${AMI_USER} already exists; preserving its existing configuration"
    fi

    if ! grep -Eq '^[[:space:]]*#include[[:space:]]+manager_custom\.conf[[:space:]]*$' "${manager_conf}" 2>/dev/null; then
        printf '\n#include manager_custom.conf\n' >> "${manager_conf}"
    fi

    sed -i \
        -e "s#^[[:space:]]*.*manager_user[[:space:]]*=.*#\\\$manager_user   = \"${AMI_USER}\";#" \
        -e "s#^[[:space:]]*.*manager_secret[[:space:]]*=.*#\\\$manager_secret = \"${AMI_SECRET}\";#" \
        "${WEB_ROOT}/config.php"

    if command -v systemctl >/dev/null 2>&1; then
        systemctl reload asterisk 2>/dev/null || log "WARNING: Could not reload Asterisk automatically"
    elif command -v service >/dev/null 2>&1; then
        service asterisk reload 2>/dev/null || log "WARNING: Could not reload Asterisk automatically"
    fi
}

configure_cron() {
    local cron_file
    cron_file="$(mktemp)"
    trap 'rm -f "${cron_file}"' RETURN

    (crontab -l 2>/dev/null || true) |
        grep -vF "/usr/local/parseloglite/parselog.php convertlocal" > "${cron_file}" || true
    printf '%s\n' "${CRON_ENTRY}" >> "${cron_file}"
    crontab "${cron_file}"
    rm -f "${cron_file}"
    trap - RETURN
}

main() {
    [[ "${EUID}" -eq 0 ]] || fail "Run this installer as root"

    for command in mysql mysqladmin sed tar crontab; do
        require_command "${command}"
    done

    [[ -d "${SCRIPT_DIR}/html" ]] || fail "Asternic html directory not found"
    [[ -d "${SCRIPT_DIR}/parselog" ]] || fail "Asternic parselog directory not found"
    [[ -f "${SCRIPT_DIR}/sql/qstats.sql" ]] || fail "Asternic SQL schema not found"

    local db_password
    db_password="$(read_issabel_mysql_password)"

    log "=== Installing Asternic Call Center Stats Lite ==="
    configure_database "${db_password}"
    install_files "${db_password}"
    configure_ami
    configure_cron

    if command -v issabel-menumerge >/dev/null 2>&1 && [[ -f "${SCRIPT_DIR}/asternic.xml" ]]; then
        issabel-menumerge "${SCRIPT_DIR}/asternic.xml" || fail "Issabel menu merge failed"
    else
        log "WARNING: issabel-menumerge or asternic.xml is unavailable; add the Queue Stats menu manually"
    fi

    if id asterisk >/dev/null 2>&1; then
        chown -R asterisk:asterisk "${WEB_ROOT}" "${PARSELOG_ROOT}"
    fi
    chmod -R u=rwX,go=rX "${WEB_ROOT}" "${PARSELOG_ROOT}"

    log "Asternic installation completed: https://<issabel-host>/queue-stats/"
}

main "$@"
