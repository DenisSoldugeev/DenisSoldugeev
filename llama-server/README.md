# llama-server

Local LLM on Linux — [llama.cpp](https://github.com/ggml-org/llama.cpp) (Vulkan)
serving **Qwen2.5-14B-Instruct** on an RTX 3060 (12 GB), managed as a
`systemd --user` service with a `make` wrapper.

- Web UI + OpenAI-compatible API on `http://localhost:8080` (`/v1/chat/completions`)
- 64K context (YaRN-extended from the model's native 32K), q8 KV cache + flash-attn
  to fit 12 GB VRAM
- Auto-starts on boot, restarts on failure

## Contents

| File | Target | Purpose |
|------|--------|---------|
| `serve.sh` | `~/llama.cpp/serve.sh` | launches `llama-server` with the tuned flags |
| `llama.service` | `~/.config/systemd/user/llama.service` | systemd --user unit (autostart, restart-on-failure) |
| `Makefile` | `~/Makefile` | `make llama-*` wrapper over `systemctl --user` |
| `install.sh` | — | lays all of the above into place, reloads + enables the unit |

## Install

```sh
./install.sh
make llama-start
```

## Usage

```sh
make                 # command list + live status
make llama-start     # start
make llama-stop      # stop
make llama-restart   # restart
make llama-status    # active/inactive + URL
make llama-logs      # live logs (Ctrl+C to exit)
make llama-tail      # last 50 log lines
make llama-ps        # processes + memory
make llama-enable    # autostart on boot
make llama-disable   # disable autostart
make llama-url       # open the web UI
```

## Requirements

Not tracked in this repo (too large) — provide them separately:

| What | Expected path | How |
|------|---------------|-----|
| llama.cpp Vulkan build | `~/llama.cpp/llama-b9536/` | prebuilt Vulkan release from [llama.cpp releases](https://github.com/ggml-org/llama.cpp/releases) (NOT CUDA — no CUDA Linux builds; Vulkan accelerates on NVIDIA without the cuda-toolkit) |
| Model weights | `~/models/Qwen2.5-14B-Instruct-Q4_K_M.gguf` | download the Q4_K_M GGUF (~8.4 GB) |

Vulkan runtime (`vulkan-icd-loader` + the NVIDIA driver's Vulkan ICD) must be present.

## Notes

- ~11 tok/s at 64K context (some layers offloaded to CPU), ~11 GB VRAM.
  At 8K context with full GPU offload it was ~30 tok/s.
- Bound to `127.0.0.1` on purpose (local only). Tunnel from another host with
  `ssh -fN -L 8090:127.0.0.1:8080 user@host`.
- Swap the model by dropping another `.gguf` in `~/models/` and updating
  `MODEL` (and the build path `DIR`) in `serve.sh`.
