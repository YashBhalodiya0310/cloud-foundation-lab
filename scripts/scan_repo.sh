
#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  scan_repo.sh [--path DIR] [--log FILE] [--ext LIST] [--help]

Scans a directory and prints file counts.
Excludes: .git, .venv

Options:
  --path DIR     Directory to scan (default: .)
  --log FILE     Also write output to FILE
  --ext LIST     Comma-separated extensions to count (e.g. txt,md). Optional.
  --help         Show this help

Examples:
  ./scripts/scan_repo.sh
  ./scripts/scan_repo.sh --path ~/cloud-foundation-lab
  ./scripts/scan_repo.sh --ext txt,md
  ./scripts/scan_repo.sh --path . --log day2/scan.log
USAGE
}

TARGET="."
LOG_FILE=""
EXT_LIST=""
MAX_FILES=50
# Simple arg parser
while [[ $# -gt 0 ]]; do
  case "$1" in
    --path)
      TARGET="${2:-}"
      shift 2
      ;;
    --log)
      LOG_FILE="${2:-}"
      shift 2
      ;;
    --ext)
      EXT_LIST="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "ERROR: Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ -z "${TARGET}" || ! -d "${TARGET}" ]]; then
  echo "ERROR: --path must be an existing directory. Got: '${TARGET}'" >&2
  exit 2
fi

# logging helper
log() {
  if [[ -n "${LOG_FILE}" ]]; then
    printf "%s\n" "$*" | tee -a "${LOG_FILE}"
  else
    printf "%s\n" "$*"
  fi
}

# Reset log file at start (if logging enabled)
if [[ -n "${LOG_FILE}" ]]; then
  : > "${LOG_FILE}"
fi

# find command base (exclusions)
FIND_BASE=(find "${TARGET}" -type f -not -path "*/.git/*" -not -path "*/.venv/*")

log "==============================="
log "Repo Scan Started"
log "Time: $(date)"
log "Target: ${TARGET}"
if [[ -n "${LOG_FILE}" ]]; then
  log "Log: ${LOG_FILE}"
fi
log "==============================="

TOTAL_FILES=$("${FIND_BASE[@]}" | wc -l | tr -d ' ')
log "Total files: ${TOTAL_FILES}"

TXT_FILES=$("${FIND_BASE[@]}" -name "*.txt" | wc -l | tr -d ' ')
MD_FILES=$("${FIND_BASE[@]}" -name "*.md" | wc -l | tr -d ' ')
log "Text files:  ${TXT_FILES}"
log "Markdown:    ${MD_FILES}"

if [[ -n "${EXT_LIST}" ]]; then
  log "-------------------------------"
  log "Extension breakdown:"
  IFS=',' read -r -a EXTS <<< "${EXT_LIST}"
  for ext in "${EXTS[@]}"; do
    ext="${ext#.}"
    count=$("${FIND_BASE[@]}" -name "*.${ext}" | wc -l | tr -d ' ')
    log "  .${ext}: ${count}"
  done
fi

log "==============================="
log "Quality Gates"

# Gate 1 — File count limit
if (( TOTAL_FILES > MAX_FILES )); then
  log "❌ FAIL: File count (${TOTAL_FILES}) exceeds limit (${MAX_FILES})"
  exit 10
else
  log "✅ PASS: File count within limit (${MAX_FILES})"
fi

# Gate 2 — Secret file detection
ENV_COUNT=$("${FIND_BASE[@]}" -name ".env" | wc -l | tr -d ' ')
if (( ENV_COUNT > 0 )); then
  log "❌ FAIL: Detected ${ENV_COUNT} .env file(s) — potential secret leak"
  exit 20
else
  log "✅ PASS: No .env files detected"
fi

log "==============================="
log "Scan Completed"
exit 0
