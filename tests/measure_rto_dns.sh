#!/usr/bin/env bash
# measure_rto_dns.sh — RTO via dig against Route 53 nameserver directly
# Usage: DNS_TTL=60 bash measure_rto_dns.sh

set -euo pipefail

NS="ns-278.awsdns-34.com"
HOST="leomulticloud.internal"
SECONDARY_IP="20.107.192.8"
TTL="${DNS_TTL:-60}"
POLL=5

RUN_ID="$(date -u +%Y%m%dT%H%M%SZ)"
OUT="$(dirname "$0")/results/rto_dns_ttl${TTL}_${RUN_ID}.csv"
mkdir -p "$(dirname "$0")/results"

echo "dns_host,poll_time_utc,elapsed_sec,resolved_ip,failover_detected" > "$OUT"

START="$(date +%s%3N)"

echo "========================================"
echo "  DNS Failover RTO Test — TTL=${TTL}s"
echo "  Polling: dig @${NS} ${HOST} every ${POLL}s"
echo "  Failover when IP = ${SECONDARY_IP}"
echo "========================================"
echo ""
echo "Press ENTER — then IMMEDIATELY stop EC2 flask-weather-app"
read -r

FAILOVER=0

while true; do
  NOW="$(date +%s%3N)"
  NOW_UTC="$(date -u +%T)"
  ELAPSED=$(( (NOW - START) / 1000 ))

  RESOLVED="$(dig @${NS} ${HOST} A +short 2>/dev/null | head -1)"
  RESOLVED="${RESOLVED:-timeout}"

  echo "${HOST},${NOW_UTC},${ELAPSED},${RESOLVED},${FAILOVER}" >> "$OUT"
  echo "[+${ELAPSED}s] ${NOW_UTC} — resolved: ${RESOLVED}"

  if [[ "$RESOLVED" == "$SECONDARY_IP" && "$FAILOVER" == "0" ]]; then
    FAILOVER=1
    echo ""
    echo "========================================"
    echo "  FAILOVER DETECTED — RTO: ${ELAPSED}s"
    echo "  DNS now resolves to Azure: ${RESOLVED}"
    echo "  Results: ${OUT}"
    echo "========================================"
    echo ""
    echo "Ctrl+C to stop."
  fi

  sleep "$POLL"
done
