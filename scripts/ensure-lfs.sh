#!/usr/bin/env bash
set -euo pipefail

MODEL_FILE="example/assets/models/model_ex_ariana_fast.dm"
MIN_REAL_SIZE=$((50 * 1024 * 1024))

fail() {
  echo
  echo "ERROR: $1"
  echo
  exit 1
}

if [[ ! -f "$MODEL_FILE" ]]; then
  fail "Missing required model file: $MODEL_FILE"
fi

size="$(wc -c < "$MODEL_FILE" | tr -d ' ')"
if [[ "$size" -ge "$MIN_REAL_SIZE" ]]; then
  exit 0
fi

if ! head -c 256 "$MODEL_FILE" | grep -q "git-lfs.github.com/spec/v1"; then
  fail "Model file is too small (${size} bytes). Expected a real LFS asset: $MODEL_FILE"
fi

echo
echo "Git LFS pointer detected for $MODEL_FILE (size=${size} bytes)."

if ! command -v git >/dev/null 2>&1; then
  fail "git is not installed or not on PATH."
fi

if ! git lfs version >/dev/null 2>&1; then
  fail $'Git LFS is not installed or not on PATH.\nInstall it, then run:\n  git lfs install\n  git lfs pull'
fi

echo "git-lfs found. Fetching LFS objects..."
git lfs install
git lfs pull --include="example/assets/models/**,example/android/app/src/main/assets/**,example/ios/*.onnx,example/ios/*.dm"

size_after="$(wc -c < "$MODEL_FILE" | tr -d ' ')"
if [[ "$size_after" -lt "$MIN_REAL_SIZE" ]]; then
  fail $'git lfs pull ran but the model is still not present.\nTry:\n  git lfs pull\n  git lfs checkout'
fi

echo "LFS OK. $MODEL_FILE is now ${size_after} bytes."
