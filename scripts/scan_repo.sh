#!/usr/bin/env bash
set -euo pipefail

# -----------------------------
# Repo Scanner (Foundation Lab)
# -----------------------------
# What it does:
# - Counts files (excluding .git and .venv)
# - Optional extension breakdown
# - Quality gates:
#   - file count limit
#   - no .env files
#   - basic secret pattern detection
# - Optional logging
# - Optional JSON output for CI/automation

usage() {
  cat <<'USAGE'
Usage:
  ./scripts/scan_repo.sh [--path DIR] [--log FILE] [--ext LIST] [--json FILE] [--help]

Options:
  --path DIR     Directory to scan (default: .)
  --log FILE     Also write output to FILE (appends)
  --ext LIST     Comma-separated extensions to count (e.g. txt,md). Optional.
  --json FILE    Write a JSON report to FILE (overwrites)
  --help         Show this help

Notes:
  Excludes: .git, .venv
  Exit codes:
    0  = PASS
    20 = FAIL (quality gate violation / potential secret leak)
    2  = bad args / invalid path
USAGE
}

TARGET="."
LOG_FILE=""
EXT_LIST=""
JSON_FILE=""

# logging helper: prints to stdout + optionally appends to log file
log() {
  if [[ -n "${LOG_FILE}" ]]; then
    printf "%s\n" "$*" | tee -a "${LOG_FILE}"
  else
    printf "%s\n" "$*"
  fi
}

# JSON escape helper (minimal)
json_escape() {
  # escape backslashes + quotes
  printf "%s" "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

# arg parser
while [[ $# -gt 0 ]]; do
  case "$1" in
    --path) TARGET="${2:-}"; shift 2 ;;
    --log)  LOG_FILE="${2:-}"; shift 2 ;;
    --ext)  EXT_LIST="${2:-}"; shift 2 ;;
    --json) JSON_FILE="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "ERROR: Unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

if [[ -z "${TARGET}" || ! -d "${TARGET}" ]]; then
  echo "ERROR: --path must be an existing directory. Got: '${TARGET}'" >&2
  exit 2
fi

# if log file set, truncate it first so runs are clean
if [[ -n "${LOG_FILE}" ]]; then
  : > "${LOG_FILE}"
fi

# exclusions
FIND_BASE=(find "${TARGET}" -type f -not -path "*/.git/*" -not -path "*/.venv/*")

log "==============================="
log "Repo Scan Started"
log "Time: $(date)"
log "Target: ${TARGET}"
if [[ -n "${LOG_FILE}" ]]; then log "Log: ${LOG_FILE}"; fi
log "==============================="

TOTAL_FILES=$("${FIND_BASE[@]}" | wc -l | tr -d ' ')
TXT_FILES=$("${FIND_BASE[@]}" -name "*.txt" | wc -l | tr -d ' ')
MD_FILES=$("${FIND_BASE[@]}" -name "*.md" | wc -l | tr -d ' ')

log "Total files: ${TOTAL_FILES}"
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

# -----------------------------
# Quality Gates
# -----------------------------
log "==============================="
log "Quality Gates"

FAIL=0
FAIL_REASONS=()

# Gate 1: file count limit (simple sanity cap for labs)
MAX_FILES=50
if [[ "${TOTAL_FILES}" -le "${MAX_FILES}" ]]; then
  log "✅ PASS: File count within limit (${MAX_FILES})"
else
  log "❌ FAIL: File count ${TOTAL_FILES} exceeds limit (${MAX_FILES})"
  FAIL=1
  FAIL_REASONS+=("file_count_exceeded")
fi

# Gate 2: .env file detection (common secret leak)
ENV_COUNT=$("${FIND_BASE[@]}" -name ".env" | wc -l | tr -d ' ')
if [[ "${ENV_COUNT}" -eq 0 ]]; then
  log "✅ PASS: No .env files detected"
else
  log "❌ FAIL: Detected ${ENV_COUNT} .env file(s) — potential secret leak"
  FAIL=1
  FAIL_REASONS+=("env_file_detected")
fi

# Gate 3: basic secret pattern scan (fast + crude on purpose)
# We scan common text-y files only to avoid binary noise.
# NOTE: this is not a replacement for dedicated secret scanners, it's a baseline guard.
SECRET_HITS=0
SECRET_EXAMPLES=()

# Candidate files (small list of extensions; adjust later if needed)
CANDIDATES=$("${FIND_BASE[@]}" \( -name "*.py" -o -name "*.sh" -o -name "*.yml" -o -name "*.yaml" -o -name "*.json" -o -name "*.md" -o -name "*.txt" -o -name "*.env" \))

# Patterns:
# - Private key headers
# - AWS Access Key ID (AKIA/ASIA + 16 chars) (basic)
# - Common token keywords (very rough)
PATTERN_PRIVATE_KEY='BEGIN (OPENSSH )?PRIVATE KEY'
PATTERN_AWS_KEY_ID='(AKIA|ASIA)[0-9A-Z]{16}'
PATTERN_TOKEN_WORDS='(aws_secret_access_key|secret_key|api_key|apikey|token)[[:space:]]*[:=]'

while IFS= read -r f; do
  [[ -z "$f" ]] && continue

  # grep quietly; if match, count and store up to 5 examples total
  if LC_ALL=C grep -nE "${PATTERN_PRIVATE_KEY}|${PATTERN_AWS_KEY_ID}|${PATTERN_TOKEN_WORDS}" "$f" >/tmp/scan_hits.$$ 2>/dev/null; then
    hits_in_file=$(wc -l </tmp/scan_hits.$$ | tr -d ' ')
    SECRET_HITS=$((SECRET_HITS + hits_in_file))
    while IFS= read -r line; do
      if [[ ${#SECRET_EXAMPLES[@]} -lt 5 ]]; then
        SECRET_EXAMPLES+=("${f}:${line}")
      fi
    done </tmp/scan_hits.$$
  fi
done <<< "${CANDIDATES}"

rm -f /tmp/scan_hits.$$ 2>/dev/null || true

if [[ "${SECRET_HITS}" -eq 0 ]]; then
  log "✅ PASS: No obvious secret patterns detected"
else
  log "❌ FAIL: Detected ${SECRET_HITS} potential secret pattern hit(s)"
  if [[ ${#SECRET_EXAMPLES[@]} -gt 0 ]]; then
    log "Examples (first ${#SECRET_EXAMPLES[@]}):"
    for ex in "${SECRET_EXAMPLES[@]}"; do
      log "  - ${ex}"
    done
  fi
  FAIL=1
  FAIL_REASONS+=("secret_pattern_detected")
fi

log "==============================="
log "Scan Completed"

# -----------------------------
# Optional JSON report
# -----------------------------
if [[ -n "${JSON_FILE}" ]]; then
  # Build minimal JSON.
  # We intentionally keep it simple to avoid dependencies (jq).
  {
    printf "{\n"
    printf '  "time": "%s",\n' "$(json_escape "$(date)")"
    printf '  "target": "%s",\n' "$(json_escape "${TARGET}")"
    printf '  "counts": {\n'
    printf '    "total_files": %s,\n' "${TOTAL_FILES}"
    printf '    "text_files": %s,\n' "${TXT_FILES}"
    printf '    "markdown_files": %s\n' "${MD_FILES}"
    printf "  },\n"
    printf '  "quality_gates": {\n'
    printf '    "max_files": %s,\n' "${MAX_FILES}"
    printf '    "env_files": %s,\n' "${ENV_COUNT}"
    printf '    "secret_hits": %s,\n' "${SECRET_HITS}"
    printf '    "status": "%s",\n' "$([[ "${FAIL}" -eq 0 ]] && echo "PASS" || echo "FAIL")"
    printf '    "fail_reasons": ['
    if [[ ${#FAIL_REASONS[@]} -gt 0 ]]; then
      for i in "${!FAIL_REASONS[@]}"; do
        sep=","
        [[ "$i" -eq 0 ]] && sep=""
        printf '%s"%s"' "${sep}" "$(json_escape "${FAIL_REASONS[$i]}")"
      done
    fi
    printf "]\n"
    printf "  },\n"
    printf '  "examples": ['
    if [[ ${#SECRET_EXAMPLES[@]} -gt 0 ]]; then
      for i in "${!SECRET_EXAMPLES[@]}"; do
        sep=","
        [[ "$i" -eq 0 ]] && sep=""
        printf '%s"%s"' "${sep}" "$(json_escape "${SECRET_EXAMPLES[$i]}")"
      done
    fi
    printf "]\n"
    printf "}\n"
  } > "${JSON_FILE}"
fi

# Final exit
if [[ "${FAIL}" -eq 0 ]]; then
  exit 0
else
  exit 20
fi
