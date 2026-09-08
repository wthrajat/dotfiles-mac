# Neovim

A small personal layer on top of [LazyVim](https://www.lazyvim.org/).

## Everyday keys

The leader key is `Space`.

- `<leader><space>` finds files.
- `<leader>/` searches project text.
- `<leader>e` opens the right-hand file explorer.
- `<leader>gg` opens LazyGit.
- `gd`, `gr`, and `K` navigate LSP definitions, references, and documentation.
- `[d` and `]d` move between diagnostics.
- `<leader>aa` toggles the current AI CLI.
- `<leader>as` selects Codex, Claude, OpenCode, or another installed CLI.
- `<leader>at` sends the current context; `<leader>av` sends a visual selection.
- `<C-.>` focuses the AI CLI from normal, insert, visual, or terminal mode.

## Maintenance

- `:Lazy` manages plugins.
- `:LazyExtras` shows optional integrations.
- `:Mason` manages language servers and developer tools.
- `:checkhealth` diagnoses the full setup.
