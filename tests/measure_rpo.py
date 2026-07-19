#!/usr/bin/env python3
"""
measure_rpo.py - Real RPO measurement for leomulticloud Phase 1.

Writes rows continuously to the primary. When the primary dies
(docker stop pg-primary), compares what was confirmed on the primary
against what arrived on the standby. The difference is the real RPO,
in rows and in seconds.

Usage:
    python3 tests/measure_rpo.py
    (then, in another terminal, kill the primary: docker stop pg-primary)
"""

import csv
import datetime
import time
import sys
import psycopg

PRIMARY_DSN = "host=localhost port=5432 user=leo password=leomulticloud dbname=weatherdb"
STANDBY_DSN = "host=localhost port=5433 user=leo password=leomulticloud dbname=weatherdb"

RATE = float(sys.argv[1]) if len(sys.argv) > 1 else 10.0  # writes/second
WRITE_INTERVAL = 1.0 / RATE
STANDBY_WAIT = 5      # seconds to let the standby settle after primary death


def now_utc():
    return datetime.datetime.now(datetime.timezone.utc)


def main():
    print("=== leomulticloud RPO measurement ===")
    print(f"Writing to primary at {RATE:g} rows/second.")
    print("Kill the primary when ready:  docker stop pg-primary")
    print("-" * 50)

    last_confirmed_id = None
    last_confirmed_at = None
    rows_written = 0

    conn = psycopg.connect(PRIMARY_DSN, autocommit=True)
    start = now_utc()

    try:
        while True:
            cur = conn.execute(
                "INSERT INTO weather_requests (city) VALUES (%s) "
                "RETURNING id, requested_at",
                ("Dublin",),
            )
            row = cur.fetchone()
            last_confirmed_id, last_confirmed_at = row[0], row[1]
            rows_written += 1
            if rows_written % 50 == 0:
                print(f"  {rows_written} rows confirmed, last id={last_confirmed_id}")
            time.sleep(WRITE_INTERVAL)
    except psycopg.OperationalError as e:
        failure_detected_at = now_utc()
        print("-" * 50)
        print(f"PRIMARY DOWN detected at {failure_detected_at.isoformat()}")
        print(f"Error: {str(e).strip()[:80]}")

    print(f"Last id CONFIRMED by primary: {last_confirmed_id}")
    print(f"Waiting {STANDBY_WAIT}s for standby to settle...")
    time.sleep(STANDBY_WAIT)

    with psycopg.connect(STANDBY_DSN) as sconn:
        cur = sconn.execute(
            "SELECT max(id), max(requested_at) FROM weather_requests"
        )
        standby_max_id, standby_max_at = cur.fetchone()

    rows_lost = (last_confirmed_id or 0) - (standby_max_id or 0)
    if last_confirmed_at and standby_max_at:
        seconds_lost = (last_confirmed_at - standby_max_at).total_seconds()
    else:
        seconds_lost = None

    print("-" * 50)
    print("=== RPO RESULT ===")
    print(f"Primary last confirmed id : {last_confirmed_id}")
    print(f"Standby last received id  : {standby_max_id}")
    print(f"Rows lost (RPO in rows)   : {rows_lost}")
    print(f"Time lost (RPO in seconds): {seconds_lost}")

    ts = now_utc().strftime("%Y%m%dT%H%M%S")
    outfile = f"tests/results/rpo_{ts}.csv"
    with open(outfile, "w", newline="") as f:
        w = csv.writer(f)
        w.writerow([
            "run_timestamp", "test_start", "rows_written",
            "primary_last_id", "standby_last_id",
            "rows_lost", "seconds_lost",
        ])
        w.writerow([
            ts, start.isoformat(), rows_written,
            last_confirmed_id, standby_max_id,
            rows_lost, seconds_lost,
        ])
    print(f"CSV saved: {outfile}")


if __name__ == "__main__":
    main()
