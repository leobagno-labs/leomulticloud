#!/usr/bin/env bash
# measure_rto.sh — RTO measurement for the leomulticloud failover experiment.
# Usage:  DNS_TTL=60 ./measure_rto.sh <dns_host> [secondary_cloud] [poll_interval_sec]
# Output: results/rto_ttl_<ttl>_run_<id>.csv

set -euo pipefail

# ── Config ────────────────────────────────────────────────────────────────────
DNS_HOST="${1:?Usage: $0 <dns_host> [secondary_cloud] [poll_interval_sec]}"
SECONDARY_CLOUD="${2:-Azure}"
POLL_INTERVAL="${3:-5}"
TTL="${DNS_TTL:-unknown}"
REQUIRED_SUCCESSES=2

# ── Output setup ──────────────────────────────────────────────────────────────
RUN_ID="$(date -u +%Y%m%dT%H%M%SZ)"
RESULTS_DIR="$(dirname "$0")/results"
OUT_FILE="$RESULTS_DIR/rto_ttl_${TTL}_run_${RUN_ID}.csv"
BODY_FILE="/tmp/rto_body_${RUN_ID}.json"

mkdir -p "$RESULTS_DIR"
trap 'rm -f "$BODY_FILE"' EXIT

# ── Helpers ───────────────────────────────────────────────────────────────────
now_utc()   { date -u +%Y-%m-%dT%H:%M:%SZ; }
now_epoch() { date +%s; }
meta()      { echo "# $*" >> "$OUT_FILE"; }
log()       { echo "[$(date -u +%T)] $*"; }

# $1=field name; reads from $BODY_FILE (caller must ensure file exists)
json_get() {
  python3 -c "import json; d=json.load(open('${BODY_FILE}')); print(d.get('${1}','unknown'))" \
    2>/dev/null || echo "unknown"
}

# ── CSV header ────────────────────────────────────────────────────────────────
# FIX: all lines written via stdout inside the group redirect — never mix
#      >> (meta) with > (group redirect) on the same file, as >> appends
#      separately and the group's stdout fd stays at offset 0, causing the
#      final echo to overwrite earlier lines.
{
  echo "# LeoMultiCloud RTO Measurement | RunID=${RUN_ID} | DNS_TTL=${TTL}"
  echo "# Host=${DNS_HOST} | Secondary=${SECONDARY_CLOUD} | Poll=${POLL_INTERVAL}s | Confirmations=${REQUIRED_SUCCESSES}"
  echo "# START_TIME_UTC=$(now_utc)"
  echo "dns_host,poll_time_utc,poll_epoch,elapsed_sec,http_status,cloud_provider,status,consecutive_successes"
} > "$OUT_FILE"

# ── Pre-flight ────────────────────────────────────────────────────────────────
cat <<INFO
========================================================
  LeoMultiCloud RTO Measurement
  Host        : $DNS_HOST
  Failover    : primary → $SECONDARY_CLOUD
  TTL         : $TTL
  Polling     : every ${POLL_INTERVAL}s
  Confirmation: ${REQUIRED_SUCCESSES} consecutive 200 responses
  Output      : $OUT_FILE
========================================================

PRE-FLIGHT: verify both cloud /health endpoints return 200.
Press ENTER to start polling — then immediately stop EC2.
INFO
read -r

# ── Poll loop ─────────────────────────────────────────────────────────────────
START_EPOCH="$(now_epoch)"
meta "FAILURE_INJECTED_TIME_UTC=$(now_utc)"
log "Polling started. Inject failure now."
echo ""

SUCCESS_COUNT=0
FAILOVER_DETECTED=0  # integer: 0=false 1=true (safe under set -e)

while true; do
  NOW_EPOCH="$(now_epoch)"
  NOW_UTC="$(now_utc)"
  ELAPSED=$(( NOW_EPOCH - START_EPOCH ))

  HTTP_STATUS="$(curl -s -o "$BODY_FILE" -w "%{http_code}" --max-time 4 \
    "http://${DNS_HOST}/health" 2>/dev/null || echo "000")"

  CLOUD="unknown"; STATUS_VAL="unknown"
  if [[ "$HTTP_STATUS" == "200" || "$HTTP_STATUS" == "503" ]]; then
    CLOUD="$(json_get cloud_provider)"
    STATUS_VAL="$(json_get status)"
  fi

  [[ "$CLOUD" == "$SECONDARY_CLOUD" && "$HTTP_STATUS" == "200" ]] \
    && SUCCESS_COUNT=$(( SUCCESS_COUNT + 1 )) || SUCCESS_COUNT=0

  echo "${DNS_HOST},${NOW_UTC},${NOW_EPOCH},${ELAPSED},${HTTP_STATUS},${CLOUD},${STATUS_VAL},${SUCCESS_COUNT}" >> "$OUT_FILE"
  log "+${ELAPSED}s  HTTP=${HTTP_STATUS}  cloud=${CLOUD}  status=${STATUS_VAL}  consecutive_ok=${SUCCESS_COUNT}"

  if (( SUCCESS_COUNT >= REQUIRED_SUCCESSES && FAILOVER_DETECTED == 0 )); then
    FAILOVER_DETECTED=1
    meta "FAILOVER_DETECTED_TIME_UTC=$(now_utc)"
    meta "RTO_SECONDS=${ELAPSED}"
    meta "SUMMARY=TTL:${TTL};RTO:${ELAPSED};POLL:${POLL_INTERVAL};SECONDARY:${SECONDARY_CLOUD}"

    cat <<DONE

========================================================
  FAILOVER DETECTED — RTO: ${ELAPSED}s
  Cloud serving    : ${CLOUD}
  Results saved to : ${OUT_FILE}
========================================================

Keep polling to confirm stability. Ctrl+C to stop.
DONE
  fi

  sleep "$POLL_INTERVAL"
done
