#!/usr/bin/env bash
# Install the llama.cpp server setup onto this machine:
# lays down serve.sh, the systemd --user unit, and the Makefile, then
# reloads systemd and enables autostart. Idempotent — safe to re-run.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "→ serve.sh    → ~/llama.cpp/serve.sh"
mkdir -p "$HOME/llama.cpp"
install -m 755 "$HERE/serve.sh" "$HOME/llama.cpp/serve.sh"

echo "→ llama.service → ~/.config/systemd/user/llama.service"
mkdir -p "$HOME/.config/systemd/user"
install -m 644 "$HERE/llama.service" "$HOME/.config/systemd/user/llama.service"

echo "→ Makefile    → ~/Makefile"
install -m 644 "$HERE/Makefile" "$HOME/Makefile"

echo "→ systemctl --user daemon-reload + enable"
systemctl --user daemon-reload
systemctl --user enable llama.service

echo
echo "Done. Start with:  make llama-start"
echo "Note: the llama.cpp Vulkan binary and the .gguf model are NOT in this repo."
echo "      Expected at ~/llama.cpp/llama-b9536/ and ~/models/ (see README)."
