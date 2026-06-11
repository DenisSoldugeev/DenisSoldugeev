#!/usr/bin/env bash
# Start a local llama.cpp server via Vulkan (RTX 3060).
# Used by the systemd --user unit. For interactive use, prefer llama-mgr.
# Web UI + OpenAI-compatible API: http://localhost:8080
set -e

LLAMA_DIR="$HOME/llama.cpp"

# Auto-detect the latest installed build (e.g. llama-b9596).
# Vulkan builds — no CUDA toolkit required; Vulkan gives GPU acceleration
# on NVIDIA via the standard driver ICD.
BUILD=$(ls -1 "$LLAMA_DIR" | grep -E '^llama-b[0-9]+$' | sort -t b -k2 -n | tail -1)
DIR="$LLAMA_DIR/$BUILD"
MODEL="$HOME/models/Qwen2.5-14B-Instruct-Q4_K_M.gguf"

cd "$DIR"
# ctx 65536 — extended via YaRN from the model's native 32K.
# q8 KV cache + flash-attn fits into 12 GB VRAM (RTX 3060).
LD_LIBRARY_PATH="$DIR" ./llama-server \
  --model         "$MODEL" \
  --ctx-size      65536 \
  --parallel      1 \
  --rope-scaling  yarn \
  --yarn-orig-ctx 32768 \
  --cache-type-k  q8_0 \
  --cache-type-v  q8_0 \
  --flash-attn    on \
  --host          127.0.0.1 \
  --port          8080 \
  --jinja
