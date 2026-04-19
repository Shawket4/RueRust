#!/usr/bin/env bash
#
# download_menu_images.sh
#
# Parses a Talabat-style menu JSON and downloads each item's originalImage,
# naming the file after the item's `name` field.
#
# Deduplicates by `id` so items that appear in multiple sections
# (e.g. "Picks for you") are only downloaded once.
#
# Works with:
#   - A full JSON document: { "menuData": { "items": [...] } }
#   - A fragment starting with `"menuData": { ... }` (auto-wrapped)
#   - Any JSON where an `items` array exists at any depth
#
# Compatible with macOS default bash 3.2.
#
# Usage:
#   ./download_menu_images.sh menu.json [output_dir]
#
# Requires: jq, curl

set -euo pipefail

# ---------- args ----------
INPUT_JSON="${1:-menu.json}"
OUTPUT_DIR="${2:-menu_images}"

if [[ ! -f "$INPUT_JSON" ]]; then
    echo "Error: input file not found: $INPUT_JSON" >&2
    exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
    echo "Error: 'jq' is required but not installed. Install with: brew install jq" >&2
    exit 1
fi

mkdir -p "$OUTPUT_DIR"

# ---------- helpers ----------
sanitize() {
    local s="$1"
    s="${s#"${s%%[![:space:]]*}"}"
    s="${s%"${s##*[![:space:]]}"}"
    s=$(printf '%s' "$s" | sed -E 's/[^A-Za-z0-9 _-]+/_/g; s/ +/ /g')
    printf '%s' "$s"
}

url_ext() {
    local url="$1"
    local path="${url%%\?*}"
    local base="${path##*/}"
    if [[ "$base" == *.* ]]; then
        printf '%s' "${base##*.}" | tr '[:upper:]' '[:lower:]'
    else
        printf 'jpg'
    fi
}

# Run jq against the input, auto-wrapping the file if it's a fragment.
run_jq() {
    local filter="$1"
    if jq -e . "$INPUT_JSON" >/dev/null 2>&1; then
        jq -r "$filter" "$INPUT_JSON"
    else
        { printf '{'; cat "$INPUT_JSON"; printf '}'; } | jq -r "$filter"
    fi
}

# ---------- main ----------
# Find the first `items` array at any depth, dedupe by id, emit TSV.
JQ_FILTER='
  ( first( .. | .items? | arrays ) // [] )
  | unique_by(.id)
  | map(select(.originalImage != null and .originalImage != ""))
  | .[]
  | [ (.id|tostring), .name, .originalImage ]
  | @tsv
'

# bash 3.2 compat: while-read loop instead of mapfile.
ROWS=()
while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    ROWS+=("$line")
done < <(run_jq "$JQ_FILTER")

total=${#ROWS[@]}
if [[ $total -eq 0 ]]; then
    echo "No items found in $INPUT_JSON." >&2
    echo "Tip: make sure the file contains an 'items' array somewhere." >&2
    exit 1
fi

echo "Found $total unique items with images. Saving to: $OUTPUT_DIR"
echo

ok=0
fail=0
skip=0
i=0

for row in "${ROWS[@]}"; do
    i=$((i + 1))
    IFS=$'\t' read -r id name url <<<"$row"

    safe_name=$(sanitize "$name")
    [[ -z "$safe_name" ]] && safe_name="item_$id"

    ext=$(url_ext "$url")
    out="$OUTPUT_DIR/${safe_name}.${ext}"

    if [[ -e "$out" ]]; then
        out="$OUTPUT_DIR/${safe_name}_${id}.${ext}"
    fi

    if [[ -s "$out" ]]; then
        printf '[%d/%d] SKIP  %s (already exists)\n' "$i" "$total" "$out"
        skip=$((skip + 1))
        continue
    fi

    printf '[%d/%d] GET   %s\n' "$i" "$total" "$name"
    if curl -fsSL \
            -A 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36' \
            --retry 3 --retry-delay 1 \
            --max-time 30 \
            -o "$out" "$url"; then
        ok=$((ok + 1))
    else
        printf '      FAIL  %s -> %s\n' "$name" "$url" >&2
        rm -f "$out"
        fail=$((fail + 1))
    fi
done

echo
echo "Done. Downloaded: $ok  Skipped: $skip  Failed: $fail"
