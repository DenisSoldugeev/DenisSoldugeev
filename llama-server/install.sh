#!/usr/bin/env bash
# Install the llama.cpp server setup onto this machine.
# Idempotent — safe to re-run.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "→ serve.sh      → ~/llama.cpp/serve.sh"
mkdir -p "$HOME/llama.cpp"
install -m 755 "$HERE/serve.sh" "$HOME/llama.cpp/serve.sh"

echo "→ llama-mgr.sh  → ~/llama.cpp/llama-mgr.sh"
install -m 755 "$HERE/llama-mgr.sh" "$HOME/llama.cpp/llama-mgr.sh"

# Only create the conf if it doesn't exist — don't clobber local tuning.
if [[ ! -f "$HOME/llama.cpp/llama-mgr.conf" ]]; then
  echo "→ llama-mgr.conf → ~/llama.cpp/llama-mgr.conf  (created from template)"
  install -m 644 "$HERE/llama-mgr.conf" "$HOME/llama.cpp/llama-mgr.conf"
else
  echo "→ llama-mgr.conf already exists, skipping"
fi

echo "→ ~/bin/llama-mgr → ~/llama.cpp/llama-mgr.sh  (symlink)"
mkdir -p "$HOME/bin"
ln -sf "$HOME/llama.cpp/llama-mgr.sh" "$HOME/bin/llama-mgr"

echo "→ llama.service  → ~/.config/systemd/user/llama.service"
mkdir -p "$HOME/.config/systemd/user"
install -m 644 "$HERE/llama.service" "$HOME/.config/systemd/user/llama.service"

echo "→ Makefile       → ~/Makefile"
install -m 644 "$HERE/Makefile" "$HOME/Makefile"

echo "→ systemctl --user daemon-reload + enable"
systemctl --user daemon-reload
systemctl --user enable llama.service

echo
echo "Done."
echo "  Direct control:  llama-mgr start"
echo "  Systemd:         make llama-start"
echo
echo "Note: the llama.cpp Vulkan binary and .gguf models are NOT in this repo."
echo "      Expected at ~/llama.cpp/llama-b<N>/ and ~/models/ (see README)."
