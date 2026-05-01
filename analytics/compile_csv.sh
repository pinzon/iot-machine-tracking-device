#!/usr/bin/env bash
set -euo pipefail

export AWS_PROFILE=personal

BUCKET="machine-tracker-iot-data-logs"
PREFIX="machine_durations/"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
OUTPUT="${1:-${SCRIPT_DIR}/compiled.csv}"
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

echo "Syncing s3://${BUCKET}/${PREFIX} -> ${TMPDIR}"
aws s3 sync "s3://${BUCKET}/${PREFIX}" "$TMPDIR" --quiet

shopt -s globstar nullglob
files=( "$TMPDIR"/**/*.csv )

if [[ ${#files[@]} -eq 0 ]]; then
  echo "No CSV files found in s3://${BUCKET}/${PREFIX}" >&2
  exit 1
fi

# Header from first file; rows from all files sorted by path (filename = ISO timestamp)
head -n 1 "${files[0]}" > "$OUTPUT"
printf '%s\n' "${files[@]}" | sort | while read -r f; do
  tail -n +2 "$f" >> "$OUTPUT"
done

rows=$(($(wc -l < "$OUTPUT") - 1))
echo "Wrote ${OUTPUT} (${#files[@]} files, ${rows} rows)"
