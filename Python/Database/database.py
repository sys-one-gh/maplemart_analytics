"""SQL Server connectivity via pyodbc. Nothing else in the codebase should
import pyodbc directly - go through get_connection() / repository.py.
"""
from contextlib import contextmanager

import pyodbc

from Configuration.config import DATABASE
from Configuration.logging_setup import get_logger

log = get_logger(__name__)

# unixODBC's connection pooling can hand back a physical connection that
# still has an unconsumed result set from an unrelated earlier query,
# raising "Connection is busy with results for another command" on an
# otherwise-fresh pyodbc.connect() call. Pooling isn't needed here - each
# pipeline run makes a handful of short-lived connections.
pyodbc.pooling = False


@contextmanager
def get_connection():
    conn = pyodbc.connect(DATABASE.connection_string, autocommit=True)
    try:
        yield conn
    finally:
        conn.close()


def test_connection() -> bool:
    try:
        with get_connection() as conn:
            conn.execute("SELECT 1").fetchone()
        log.info("Database connection established (%s / %s)", DATABASE.server, DATABASE.database)
        return True
    except pyodbc.Error:
        log.exception("Database connection failed")
        return False


if __name__ == "__main__":
    ok = test_connection()
    print("Connected." if ok else "Connection failed - check .env / Python/Configuration/settings.json")
