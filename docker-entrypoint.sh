#!/bin/bash
set -e

# Defaults
MYSQL_HOST="${MYSQL_HOST:-mysql}"
MYSQL_PORT="${MYSQL_PORT:-3306}"
MYSQL_USER="${MYSQL_USER:-hercules}"
MYSQL_PASSWORD="${MYSQL_PASSWORD:-hercules}"
MYSQL_DATABASE="${MYSQL_DATABASE:-hercules}"

INTER_USERID="${INTER_USERID:-s1}"
INTER_PASSWORD="${INTER_PASSWORD:-p1}"

LOGIN_HOST="${LOGIN_HOST:-login-server}"
LOGIN_PORT="${LOGIN_PORT:-6900}"
CHAR_HOST="${CHAR_HOST:-char-server}"
CHAR_PORT="${CHAR_PORT:-6121}"
MAP_PORT="${MAP_PORT:-5121}"
API_PORT="${API_PORT:-7121}"

CHAR_IP="${CHAR_IP:-127.0.0.1}"
MAP_IP="${MAP_IP:-127.0.0.1}"
API_IP="${API_IP:-127.0.0.1}"

CONF_DIR="/opt/hercules/conf"
IMPORT_DIR="${CONF_DIR}/import"

mkdir -p "${IMPORT_DIR}"

# Generate sql_connection.conf (overwrites default — affects all servers)
cat > "${CONF_DIR}/global/sql_connection.conf" << EOF
sql_connection: {
	db_hostname: "${MYSQL_HOST}"
	db_port: ${MYSQL_PORT}
	db_username: "${MYSQL_USER}"
	db_password: "${MYSQL_PASSWORD}"
	db_database: "${MYSQL_DATABASE}"
}
EOF

echo "[entrypoint] SQL connection configured: ${MYSQL_USER}@${MYSQL_HOST}:${MYSQL_PORT}/${MYSQL_DATABASE}"

# Generate per-server docker config files (env-var driven, never manually edited)
# Manual overrides go in conf/import/<server>.conf which imports this docker file.
case "${SERVICE}" in
    login-server)
        cat > "${IMPORT_DIR}/login-server-docker.conf" << EOF
login_configuration: {
    inter: {
        login_port: ${LOGIN_PORT}
    }
}
EOF
        echo "[entrypoint] Login server import written"
        ;;

    char-server)
        cat > "${IMPORT_DIR}/char-server-docker.conf" << EOF
char_configuration: {
    inter: {
        userid: "${INTER_USERID}"
        passwd: "${INTER_PASSWORD}"
        login_ip: "${LOGIN_HOST}"
        login_port: ${LOGIN_PORT}
        char_ip: "${CHAR_IP}"
        char_port: ${CHAR_PORT}
    }
}
EOF
        echo "[entrypoint] Char server import written"
        ;;

    map-server)
        cat > "${IMPORT_DIR}/map-server-docker.conf" << EOF
map_configuration: {
    inter: {
        userid: "${INTER_USERID}"
        passwd: "${INTER_PASSWORD}"
        char_ip: "${CHAR_HOST}"
        char_port: ${CHAR_PORT}
        map_ip: "${MAP_IP}"
        map_port: ${MAP_PORT}
    }
}
EOF
        echo "[entrypoint] Map server import written"
        ;;

    api-server)
        cat > "${IMPORT_DIR}/api-server-docker.conf" << EOF
api_configuration: {
    inter: {
        userid: "${INTER_USERID}"
        passwd: "${INTER_PASSWORD}"
        login_ip: "${LOGIN_HOST}"
        login_port: ${LOGIN_PORT}
        char_ip: "${CHAR_HOST}"
        char_port: ${CHAR_PORT}
        api_ip: "${API_IP}"
        api_port: ${API_PORT}
    }
}
EOF
        echo "[entrypoint] API server import written"
        ;;

    *)
        echo "[entrypoint] Unknown SERVICE: ${SERVICE}"
        exit 1
        ;;
esac

# Wait for upstream dependencies
case "${SERVICE}" in
    login-server)
        echo "[entrypoint] Waiting for MySQL at ${MYSQL_HOST}:${MYSQL_PORT}..."
        until nc -z "${MYSQL_HOST}" "${MYSQL_PORT}" 2>/dev/null; do
            sleep 2
        done
        echo "[entrypoint] MySQL is ready"
        ;;

    char-server)
        echo "[entrypoint] Waiting for login server at ${LOGIN_HOST}:${LOGIN_PORT}..."
        until nc -z "${LOGIN_HOST}" "${LOGIN_PORT}" 2>/dev/null; do
            sleep 2
        done
        echo "[entrypoint] Login server is ready"
        ;;

    map-server|api-server)
        echo "[entrypoint] Waiting for char server at ${CHAR_HOST}:${CHAR_PORT}..."
        until nc -z "${CHAR_HOST}" "${CHAR_PORT}" 2>/dev/null; do
            sleep 2
        done
        echo "[entrypoint] Char server is ready"
        ;;
esac

echo "[entrypoint] Starting ${SERVICE}..."

exec "/opt/hercules/${SERVICE}" "$@"
