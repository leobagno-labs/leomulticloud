#!/usr/bin/env bash
# measure_rto.sh — RTO measurement script for the leomulticloud failover experiment.
#
# Usage:
#   ./measure_rto.sh <dns_hostname> <expected_secondary_cloud> [poll_interval_sec]
#
# Example:
#   ./measure_rto.sh app.yourdomain.com Azure 5
#
# How to use in an experiment run:
#   1. Run: terraform apply (with dns_ttl=60|120|300)
#   2. Verify both /health endpoints return 200 (see pre-flight check below)
#   3. Start this script in one terminal — it will poll immediately
#   4. In another terminal, stop the EC2 instance (AWS console or aws cli)
#   5. This script detects when Azure starts responding and prints the RTO
#
# Output:  results/rto_<ttl>s_<timestamp>.csv

set -euo pipefail

DNS_HOST="${1:-}"
SECONDARY_CLOUD="${2:-Azure}"
POLL_INTERVAL="${3:-5}"

if [[ -z "$DNS_HOST" ]]; then
  echo "Usage: $0 <dns_hostname> <expected_secondary_cloud> [poll_interval_sec]"
  exit 1
fi

RESULTS_DIR="$(dirname "$0")/results"
mkdir -p "$RESULTS_DIR"

TIMESTAMP=$(date -u +%Y%m%dT%H%M%SZ)
# TTL is embedded in the filename when you run — set it manually to match your tfvars
TTL="${DNS_TTL:-unknown}"
OUT_FILE="$RESULTS_DIR/rto_ttl${TTL}s_${TIMESTAMP}.csv"

echo "dns_host,poll_time_utc,elapsed_sec,http_status,cloud_provider,status" > "$OUT_FILE"

echo "========================================================"
echo "  LeoMultiCloud RTO Measurement"
echo "  Host    : $DNS_HOST"
echo "  Failover: primary → $SECONDARY_CLOUD"
echo "  Polling : every ${POLL_INTERVAL}s"
echo "  Output  : $OUT_FILE"
echo "========================================================"
echo ""
echo "  PRE-FLIGHT: verify both clouds are healthy before injecting failure."
echo "  Press ENTER when you are ready to start polling, then stop EC2."
echo ""
read -r

T0=""
FAILOVER_DETECTED=false
START_EPOCH=$(date +%s)

echo "[$(date -u +%T)] Polling started. Inject failure now (stop EC2 instance)."
echo ""

while true; do
  NOW_EPOCH=$(date +%s)
  NOW_UTC=$(date -u +%T)
  ELAPSED=$(( NOW_EPOCH - START_EPOCH ))

  # Query the DNS endpoint, capture HTTP status and body
  HTTP_RESPONSE=$(curl -s -o /tmp/rto_body.json -w "%{http_code}" \
    --max-time 4 \
    "http://${DNS_HOST}/health" 2>/dev/null || echo "000")

  CLOUD_PROVIDER="unknown"
  STATUS_VAL="unknown"

  if [[ "$HTTP_RESPONSE" == "200" || "$HTTP_RESPONSE" == "503" ]]; then
    CLOUD_PROVIDER=$(python3 -c "import json,sys; d=json.load(open('/tmp/rto_body.json')); print(d.get('cloud_provider','unknown'))" 2>/dev/null || echo "unknown")
    STATUS_VAL=$(python3 -c "import json,sys; d=json.load(open('/tmp/rto_body.json')); print(d.get('status','unknown'))" 2>/dev/null || echo "unknown")
  fi

  echo "$DNS_HOST,$NOW_UTC,${ELAPSED},${HTTP_RESPONSE},${CLOUD_PROVIDER},${STATUS_VAL}" >> "$OUT_FILE"
  echo "[${NOW_UTC}] +${ELAPSED}s  HTTP=${HTTP_RESPONSE}  cloud=${CLOUD_PROVIDER}  status=${STATUS_VAL}"

  # Detect failover: secondary cloud responds with 200
  if [[ "$CLOUD_PROVIDER" == "$SECONDARY_CLOUD" && "$HTTP_RESPONSE" == "200" && "$FAILOVER_DETECTED" == "false" ]]; then
    FAILOVER_DETECTED=true
    echo ""
    echo "========================================================"
    echo "  FAILOVER DETECTED at +${ELAPSED}s"
    echo "  RTO = ${ELAPSED} seconds"
    echo "  Cloud now serving: $CLOUD_PROVIDER"
    echo "  Results saved to: $OUT_FILE"
    echo "========================================================"
    echo ""
    echo "  Keep polling to confirm stability. Ctrl+C to stop."
    echo ""
  fi

  sleep "$POLL_INTERVAL"
done
