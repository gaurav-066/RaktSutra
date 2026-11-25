#!/bin/bash
# =====================================================================
# RaktSutra - Database & Dashboard Launcher
# =====================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

LOCAL_DATA_DIR="/tmp/raktkhoj_mysql"
LOCAL_SOCKET="/tmp/raktkhoj_mysql.sock"
LOCAL_PORT=3307

echo "========================================================"
echo "          RaktSutra - Blood Network System              "
echo "========================================================"

# Function to test MySQL connection
try_mysql_query() {
    local cmd="$1"
    # Try system MySQL first (socket / 3306)
    if mysql -u root -e "$cmd" >/dev/null 2>&1; then
        echo "system"
        return 0
    fi
    # Try local socket
    if mysql -u root -S "$LOCAL_SOCKET" -e "$cmd" >/dev/null 2>&1; then
        echo "local"
        return 0
    fi
    return 1
}

# Determine MySQL connection mode
MYSQL_MODE=""
if try_mysql_query "SELECT 1;" >/dev/null 2>&1; then
    MYSQL_MODE=$(try_mysql_query "SELECT 1;")
    echo "[+] MySQL server is already active (mode: $MYSQL_MODE)."
else
    echo "[!] No active MySQL server detected. Starting persistent local daemon..."
    if [ ! -d "$LOCAL_DATA_DIR" ]; then
        echo "[*] Initializing persistent data directory at $LOCAL_DATA_DIR..."
        /usr/sbin/mysqld --no-defaults --initialize-insecure --datadir="$LOCAL_DATA_DIR"
    fi
    echo "[*] Launching local mysqld daemon (socket: $LOCAL_SOCKET, port: $LOCAL_PORT)..."
    /usr/sbin/mysqld --no-defaults --datadir="$LOCAL_DATA_DIR" --socket="$LOCAL_SOCKET" --port="$LOCAL_PORT" --pid-file="/tmp/raktkhoj_mysql.pid" --bind-address=127.0.0.1 >/dev/null 2>&1 &
    
    # Wait for mysqld socket to become ready
    for i in {1..15}; do
        if [ -S "$LOCAL_SOCKET" ] && mysql -u root -S "$LOCAL_SOCKET" -e "SELECT 1;" >/dev/null 2>&1; then
            MYSQL_MODE="local"
            echo "[+] Local MySQL daemon is ready."
            break
        fi
        sleep 1
    done
fi

if [ -z "$MYSQL_MODE" ]; then
    echo "[ERROR] Could not connect to or start MySQL. Please start MySQL (e.g. sudo service mysql start) and retry."
    exit 1
fi

# Ensure blood_network schema and seed data are loaded
MYSQL_CMD="mysql -u root"
if [ "$MYSQL_MODE" = "local" ]; then
    MYSQL_CMD="mysql -u root -S $LOCAL_SOCKET"
fi

DONOR_COUNT=$($MYSQL_CMD -D blood_network -se "SELECT COUNT(*) FROM Donor;" 2>/dev/null || echo "0")
if [ "$DONOR_COUNT" = "0" ] || [ -z "$DONOR_COUNT" ]; then
    echo "[*] Database 'blood_network' is missing or unseeded. Loading 01_schema.sql and 02_seed.sql..."
    $MYSQL_CMD < 01_schema.sql
    $MYSQL_CMD < 02_seed.sql
    echo "[+] Schema and seed data successfully loaded into blood_network."
else
    echo "[+] Database 'blood_network' is populated ($DONOR_COUNT donors registered)."
fi

# Ensure Python virtual environment and dependencies
if [ ! -f "venv/bin/python3" ]; then
    echo "[*] Initializing Python virtual environment..."
    python3 -m venv venv
    ./venv/bin/pip install --quiet pymysql flask
fi

echo "========================================================"
echo "  RaktSutra Dashboard starting at: http://127.0.0.1:5000"
echo "  Press Ctrl+C to stop."
echo "========================================================"

exec ./venv/bin/python3 app.py
