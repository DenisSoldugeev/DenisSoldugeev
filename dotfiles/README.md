# dotfiles

macOS shell & terminal configuration.

## Contents

| File | Target | Purpose |
|------|--------|---------|
| `.zshrc` | `~/.zshrc` | zsh config: PATH, history, aliases, antidote plugins, starship |
| `.zsh_plugins.txt` | `~/.zsh_plugins.txt` | antidote plugin list (autosuggestions, syntax-highlighting, completions) |
| `.config/starship.toml` | `~/.config/starship.toml` | starship prompt (gruvbox-rainbow preset) |
| `gruvbox.terminal` | imported into Terminal.app | Gruvbox profile: palette, FiraCode Nerd Font Mono, transparency + blur |

## Apply

```sh
# shell
cp .zshrc ~/.zshrc
cp .zsh_plugins.txt ~/.zsh_plugins.txt
mkdir -p ~/.config && cp .config/starship.toml ~/.config/starship.toml

# Terminal.app profile (macOS): import, then set as default
open gruvbox.terminal
# Settings -> Profiles -> Gruvbox -> Default

exec zsh
```

## Requirements

`brew install starship antidote eza bat ripgrep fzf zoxide direnv` and a Nerd Font
(FiraCode Nerd Font). Prompt and icons rely on the Nerd Font glyphs.
