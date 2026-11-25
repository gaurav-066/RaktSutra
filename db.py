import json
import logging
import os
import pymysql
from pymysql.constants import CLIENT

CONFIG_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "config.json")

logger = logging.getLogger(__name__)

def load_config():
    if not os.path.exists(CONFIG_FILE):
        raise FileNotFoundError(f"Configuration file not found: {CONFIG_FILE}")
    with open(CONFIG_FILE, "r", encoding="utf-8") as f:
        return json.load(f)

def get_connection(autocommit=True):
    """
    Try to connect to MySQL using the ordered list of connection strategies
    defined in config.json. Logs a warning (not a crash) when falling back.
    """
    config = load_config()
    db_cfg = config.get("database", {})
    user     = db_cfg.get("user", "root")
    password = db_cfg.get("password", "")
    database = db_cfg.get("database", "blood_network")  

    attempts = []  # list of (label, kwargs)

    # 1. Primary unix_socket
    sock = db_cfg.get("unix_socket")
    if sock and os.path.exists(sock):
        attempts.append(("primary unix_socket", {"unix_socket": sock, "user": user, "password": password, "database": database}))

    # 2. Configured host:port
    host = db_cfg.get("host", "127.0.0.1")
    port = int(db_cfg.get("port", 3306))
    attempts.append((f"host {host}:{port}", {"host": host, "port": port, "user": user, "password": password, "database": database}))

    # 3. Fallback unix_socket
    fb_sock = db_cfg.get("fallback_socket")
    if fb_sock and os.path.exists(fb_sock):
        attempts.append(("fallback unix_socket", {"unix_socket": fb_sock, "user": user, "password": password, "database": database}))

    # 4. Fallback port
    fb_port = db_cfg.get("fallback_port")
    if fb_port:
        attempts.append((f"fallback port {fb_port}", {"host": host, "port": int(fb_port), "user": user, "password": password, "database": database}))

    last_err = None
    for label, kwargs in attempts:
        try:
            conn = pymysql.connect(
                **kwargs,
                cursorclass=pymysql.cursors.DictCursor,
                autocommit=autocommit,
                client_flag=CLIENT.MULTI_STATEMENTS
            )
            if last_err is not None:
                # We fell back — warn so it's visible in the terminal
                logger.warning("Connected via %s (primary failed: %s)", label, last_err)
            return conn
        except pymysql.MySQLError as e:
            last_err = e
            continue

    raise ConnectionError(
        f"Could not connect to MySQL using any configured method.\n"
        f"Last error: {last_err}\n"
        f"Tried: {', '.join(l for l, _ in attempts)}"
    )

# ---------------------------------------------------------------------------
# Helpers that stringify non-JSON-serialisable types (Decimal, date, etc.)
# ---------------------------------------------------------------------------

def _clean(row: dict) -> dict:
    return {k: (str(v) if v is not None else None) for k, v in row.items()}

def _clean_rows(rows) -> list:
    return [_clean(r) for r in rows]

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

def query(sql, params=None):
    """Execute a SELECT and return a list of dicts. Read-only helper."""
    conn = get_connection()
    try:
        with conn.cursor() as cur:
            cur.execute(sql, params or ())
            return _clean_rows(cur.fetchall())
    finally:
        conn.close()

def execute_raw(sql):
    """
    Execute arbitrary SQL (possibly multiple statements) and return a
    structured result list.  Used only by the interactive SQL console.
    """
    conn = get_connection()
    results = []
    try:
        with conn.cursor() as cur:
            cur.execute(sql)
            while True:
                if cur.description:
                    columns = [col[0] for col in cur.description]
                    rows    = _clean_rows(cur.fetchall())
                    results.append({"type": "select", "columns": columns,
                                    "rows": rows, "row_count": len(rows)})
                else:
                    results.append({"type": "mutation", "affected_rows": cur.rowcount})

                if not cur.nextset():
                    break

        return {"success": True, "results": results}
    except pymysql.MySQLError as err:
        return {
            "success": False,
            "error_code":    err.args[0] if err.args else None,
            "error_message": err.args[1] if len(err.args) > 1 else str(err),
        }
    finally:
        conn.close()

def call_procedure(proc_name, args=None):
    """Call a stored procedure that returns row results (no OUT params)."""
    args = args or []
    placeholders = ", ".join(["%s"] * len(args))
    sql = f"CALL {proc_name}({placeholders});" if args else f"CALL {proc_name}();"

    conn = get_connection()
    try:
        with conn.cursor() as cur:
            cur.execute(sql, tuple(args))
            rows = _clean_rows(cur.fetchall())
            return {"success": True, "data": rows}
    except pymysql.MySQLError as err:
        return {
            "success": False,
            "error_code":    err.args[0] if err.args else None,
            "error_message": err.args[1] if len(err.args) > 1 else str(err),
        }
    finally:
        conn.close()

def call_procedure_with_out(proc_name, in_args, out_vars):
    """
    Call a stored procedure that has OUT parameters.

    Example:
        call_procedure_with_out('sp_send_otp',
                                ['9333333301', 'Blood Request'],
                                ['@code'])
    Returns:
        {'success': True, 'out': {'code': '123456'}, 'data': [...]}
    """
    placeholders = ", ".join(["%s"] * len(in_args) + out_vars)
    sql_call   = f"CALL {proc_name}({placeholders});"
    # SELECT @var AS var  (strips the leading '@' for the alias)
    select_items = ", ".join(f"{v} AS {v.lstrip('@')}" for v in out_vars)
    sql_select = f"SELECT {select_items};"

    conn = get_connection()
    try:
        with conn.cursor() as cur:
            cur.execute(sql_call, tuple(in_args))
            data = _clean_rows(cur.fetchall()) if cur.description else []

            cur.execute(sql_select)
            out_row = cur.fetchone() or {}
            out     = _clean(out_row)

            return {"success": True, "out": out, "data": data}
    except pymysql.MySQLError as err:
        return {
            "success": False,
            "error_code":    err.args[0] if err.args else None,
            "error_message": err.args[1] if len(err.args) > 1 else str(err),
        }
    finally:
        conn.close()
