#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source_dir="$root/assets/readalongs"
temp_dir="$(mktemp -d)"
trap 'rm -rf "$temp_dir"' EXIT

source ../../mus_segmenter/.venv/bin/activate

sources=()
destinations=()
count=0
while IFS= read -r -d '' source; do
  relative="${source#"$source_dir"/}"
  stem="${relative%.*}"
  text="$temp_dir/$stem.txt"
  if [[ -e "$text" ]]; then
    echo "Multiple source files would produce $source_dir/$stem.json" >&2
    exit 1
  fi
  mkdir -p "$(dirname "$text")"
  python3 "$root/tools/extract_story_text.py" "$source" --output "$text"
  sources+=("$text")
  destinations+=("$source_dir/$stem.json")
  count=$((count + 1))
done < <(find "$source_dir" -type f \( -name '*.readalong' -o -name '*.eaf' \) -print0)

if (( count == 0 )); then
  echo "No ReadAlong or ELAN files found in $source_dir" >&2
  exit 1
fi

python3 "$root/tools/build_story_index.py" "${sources[@]}" "$@"
for ((i = 0; i < count; i++)); do
  cp "${sources[i]%.txt}.json" "${destinations[i]}"
  echo "Wrote ${destinations[i]}"
done
