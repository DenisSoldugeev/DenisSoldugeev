# Control local services via systemd --user.
# Usage: `make <target>` from the home directory. `make` — command list + status.

LLAMA := llama
URL   := http://localhost:8080

.DEFAULT_GOAL := help

.PHONY: help llama-start llama-stop llama-restart llama-status \
        llama-logs llama-tail llama-ps llama-enable llama-disable llama-url

help:              ## Show command list and status
	@printf "\033[1;33m🦙 llama.cpp\033[0m — Qwen2.5 14B (Vulkan/RTX 3060)  ·  $(URL)\n"
	@systemctl --user is-active $(LLAMA) >/dev/null \
	  && printf "   status: \033[32m● active\033[0m\n\n" \
	  || printf "   status: \033[31m○ inactive\033[0m\n\n"
	@grep -E '^[a-z-]+:.*##' $(MAKEFILE_LIST) | sort | \
	  awk -F':.*##' '{printf "  \033[36mmake %-14s\033[0m %s\n", $$1, $$2}'

llama-start:       ## Start the model server
	systemctl --user start $(LLAMA) && $(MAKE) -s llama-status

llama-stop:        ## Stop the model server
	systemctl --user stop $(LLAMA)

llama-restart:     ## Restart the model server
	systemctl --user restart $(LLAMA) && $(MAKE) -s llama-status

llama-status:      ## Short status (active/inactive + port)
	@systemctl --user is-active $(LLAMA) >/dev/null \
	  && printf "● llama: \033[32mactive\033[0m  →  $(URL)\n" \
	  || printf "○ llama: \033[31minactive\033[0m\n"

llama-logs:        ## Live logs (Ctrl+C to exit)
	journalctl --user -u $(LLAMA) -f

llama-tail:        ## Last 50 log lines
	journalctl --user -u $(LLAMA) -n 50 --no-pager

llama-enable:      ## Enable autostart on boot
	systemctl --user enable $(LLAMA)

llama-disable:     ## Disable autostart
	systemctl --user disable $(LLAMA)

llama-ps:          ## Show processes and memory usage
	@systemctl --user status $(LLAMA) --no-pager | sed -n '1,12p'

llama-url:         ## Open the web UI in a browser
	xdg-open $(URL) >/dev/null 2>&1 &
