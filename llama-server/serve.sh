#!/usr/bin/env bash
# Start a local Qwen2.5-14B server via llama.cpp (Vulkan / RTX 3060).
# Web UI + OpenAI-compatible API: http://localhost:8080
set -e

# Vulkan build of llama.cpp (NOT CUDA — no CUDA Linux releases; Vulkan gives
# GPU acceleration on NVIDIA without the cuda-toolkit).
DIR="$HOME/llama.cpp/llama-b9536"
MODEL="$HOME/models/Qwen2.5-14B-Instruct-Q4_K_M.gguf"

cd "$DIR"
# ctx 65536 — minimum required by the Hermes agent (>=64K).
# Qwen2.5-14B is natively 32K → extended to 64K with YaRN.
# KV cache quantized to q8 + flash-attn so it fits into 12 GB VRAM;
# no explicit -ngl: llama.cpp auto-fit splits layers across GPU/CPU.
LD_LIBRARY_PATH="$DIR" ./llama-server \
  --model "$MODEL" \
  --ctx-size 65536 \
  --parallel 1 \
  --rope-scaling yarn \
  --yarn-orig-ctx 32768 \
  --cache-type-k q8_0 \
  --cache-type-v q8_0 \
  --flash-attn on \
  --host 127.0.0.1 \
  --port 8080 \
  --jinja
