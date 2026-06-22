# whiteboard.nvim

Pin files and code snippets from Neovim onto a persistent Excalidraw whiteboard in your browser. Each git repository gets its own board — stored in Neovim's data directory, never in your projects.

## Features

- **Pin a file** — press `<leader>wa` on any buffer → a card appears on the board with the filename and repo-relative path
- **Pin a snippet** — visual-select code, press `<leader>ws` → a snippet card appears with the filename, line range, and code
- **Full Excalidraw canvas** — draw, annotate, rearrange cards freely; it's a complete whiteboard, not just a card viewer
- **Per-repo persistence** — boards are saved automatically and restored when you reopen
- **Zero project impact** — boards live in `~/.local/share/nvim/whiteboard/boards/` (Windows: `AppData\Local\nvim-data\...`), not in your repos

## Requirements

- Neovim 0.9+
- Node.js 18+ (`node` on your PATH)
- curl (ships with Windows 11, macOS, most Linux)

## Installation

### lazy.nvim

```lua
{
  'your-username/whiteboard.nvim',
  config = function()
    require('whiteboard-nvim').setup()
  end,
  build = 'cd server && npm install',
}
```

The `build` command installs the server's runtime dependency (`ws`) — runs once after install. The Excalidraw frontend is pre-built and committed to the repo; no build step needed by end users.

### Verify

```
:checkhealth whiteboard
```

## Usage

| Keymap | Mode | Action |
|--------|------|--------|
| `<leader>wa` | normal | Pin current file to board |
| `<leader>ws` | visual | Pin selected code to board |
| `<leader>wo` | normal | Open board in browser |

Commands: `:WhiteboardOpen`, `:WhiteboardAddFile`, `:WhiteboardAddSnippet`, `:WhiteboardClose`, `:WhiteboardReset`

## Configuration

```lua
require('whiteboard-nvim').setup({
  keymaps = {
    add_file    = '<leader>wa',
    add_snippet = '<leader>ws',
    open        = '<leader>wo',
  },
  server = {
    port      = 0,     -- 0 = OS-assigned random port
    auto_open = true,  -- open browser on first pin
  },
  ui = {
    card_width     = 300,
    snippet_width  = 420,
    card_height    = 120,
    snippet_height = 200,
    row_gap        = 40,
    col_gap        = 40,
    cards_per_row  = 4,
  },
})
```

## How it works

```
Neovim (Lua) → HTTP POST (curl) → Node.js server → WebSocket → Browser (Excalidraw)
                                        ↕
                               nvim-data/whiteboard/boards/<hash>.json
```

The plugin spawns a lightweight Node.js server on first use. When you pin a file or snippet, the Lua plugin sends the card data via `curl` to the server, which positions the card on the Excalidraw canvas and broadcasts it over WebSocket to any open browser tabs. The board is saved to disk automatically after each change.
