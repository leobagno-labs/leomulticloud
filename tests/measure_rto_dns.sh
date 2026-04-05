#!/usr/bin/env bash
# measure_rto_dns.sh — RTO via dig against Route 53 nameserver directly
# Timer starts EXACTLY when ENTER is pressed (failure injection moment)

set -euo pipefail

NS="8.8.8.8"
HOST="leomulticloud.click"
SECONDARY_IP="20.107.192.8"
TTL="${DNS_TTL:-60}"
POLL=5

RUN_ID="$(date -u +%Y%m%dT%H%M%SZ)"
OUT="$(dirname "$0")/results/rto_dns_ttl${TTL}_${RUN_ID}.csv"
mkdir -p "$(dirname "$0")/results"

echo "dns_host,poll_time_utc,elapsed_ms,resolved_ip,failover_detected" > "$OUT"

echo "========================================"
echo "  DNS Failover RTO Test — TTL=${TTL}s"
echo "  Polling: dig @${NS} ${HOST} every ${POLL}s"
echo "  Failover when IP = ${SECONDARY_IP}"
echo "========================================"
echo ""
echo "Press ENTER — then IMMEDIATELY stop EC2 flask-weather-app"
read -r

# Timer starts HERE — exactly when ENTER is pressed
START="$(date +%s%3N)"
echo "Timer started at $(date -u +%T) UTC"
echo ""

FAILOVER=0

while true; do
  NOW="$(date +%s%3N)"
  NOW_UTC="$(date -u +%T)"
  ELAPSED_MS=$(( NOW - START ))
  ELAPSED_S=$(( ELAPSED_MS / 1000 ))

  RESOLVED="$(dig @${NS} ${HOST} A +short 2>/dev/null | head -1)"
  RESOLVED="${RESOLVED:-timeout}"

  echo "${HOST},${NOW_UTC},${ELAPSED_MS},${RESOLVED},${FAILOVER}" >> "$OUT"
  echo "[+${ELAPSED_S}s] ${NOW_UTC} — resolved: ${RESOLVED}"

  if [[ "$RESOLVED" == "$SECONDARY_IP" && "$FAILOVER" == "0" ]]; then
    FAILOVER=1
    echo ""
    echo "========================================"
    echo "  FAILOVER DETECTED — RTO: ${ELAPSED_S}s (${ELAPSED_MS}ms)"
    echo "  DNS now resolves to Azure: ${RESOLVED}"
    echo "  Results: ${OUT}"
    echo "========================================"
    echo ""
    echo "Ctrl+C to stop."
  fi

  sleep "$POLL"
done
