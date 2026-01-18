#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  scan_repo.sh [PATH]

Scans a directory (default: current directory) and prints file counts.
Excludes: .git, .venv

Examples:
  ./scripts/scan_repo.sh
  ./scripts/scan_repo.sh ~/cloud-foundation-lab
EOF
}

TARGET="${1:-.}"

if [[ "${TARGET}" == "-h" || "${TARGET}" == "--help" ]]; then
  usage
  exit 0
fi

if [[ ! -d "${TARGET}" ]]; then
  echo "ERROR: Path is not a directory: ${TARGET}" >&2
  exit 2
fi

echo "==============================="
echo "Repo Scan Started"
echo "Time: $(date)"
echo "Target: ${TARGET}"
echo "==============================="

TOTAL_FILES=$(find "${TARGET}" -type f \
  -not -path "*/.git/*" -not -path "*/.venv/*" | wc -l | tr -d ' ')
TXT_FILES=$(find "${TARGET}" -type f -name "*.txt" \
  -not -path "*/.git/*" -not -path "*/.venv/*" | wc -l | tr -d ' ')
MD_FILES=$(find "${TARGET}" -type f -name "*.md" \
  -not -path "*/.git/*" -not -path "*/.venv/*" | wc -l | tr -d ' ')

echo "Total files: $TOTAL_FILES"
echo "Text files:  $TXT_FILES"
echo "Markdown:    $MD_FILES"
echo "==============================="
echo "Scan Completed"
