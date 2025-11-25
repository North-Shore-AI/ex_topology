#!/usr/bin/env bash
set -euo pipefail

if ! command -v mix >/dev/null 2>&1; then
  echo "mix is required to run the examples." >&2
  exit 1
fi

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
EXAMPLES_DIR="${ROOT_DIR}/examples"

cd -- "${ROOT_DIR}"

mapfile -t examples < <(find "${EXAMPLES_DIR}" -maxdepth 1 -type f -name '*.exs' -print | sort)

if [ "${#examples[@]}" -eq 0 ]; then
  echo "No .exs files found under ${EXAMPLES_DIR}" >&2
  exit 1
fi

echo "Running ${#examples[@]} .exs example(s)..."

for example in "${examples[@]}"; do
  rel_path="${example#${ROOT_DIR}/}"
  echo "==> mix run ${rel_path}"
  mix run "${rel_path}"
  echo
done

echo "All examples completed."
