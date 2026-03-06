# hotline.nvim

Highlights line backgrounds based on git history frecency — lines touched frequently and recently glow hot; lines untouched for years stay cold.

Requires Neovim 0.10+ and git.

## Installation

```lua
return { 'JoshuaDueck/hotline.nvim' }
```

With options:

```lua
return {
  'JoshuaDueck/hotline.nvim',
  config = function()
    require('hotline').setup({
      method = 'frecency',
      scale = {
        min = '#0f111a',
        mid = '#1a2940',
        max = '#e85d04',
      },
      relativity = {
        mode = 'file',
      },
    })
  end,
}
```

## Configuration

```lua
require('hotline').setup({
  -- Scoring method
  -- "recency"   score by how recently each line was last touched (fastest)
  -- "frequency" score by how many times each line has been touched
  -- "frecency"  combination of frequency and recency (default)
  method = "frecency",

  -- Highlight color scale (any valid hex color)
  scale = {
    min = "#0f111a",  -- cold: rarely / long-ago touched
    mid = "#1a2940",  -- warm
    max = "#e85d04",  -- hot:  frequently / recently touched
  },

  -- How scores are normalised
  relativity = {
    -- "file" normalises against the coldest/hottest line in the file
    -- "time" normalises against an absolute time window
    mode = "file",
    -- For "time" mode: seconds of age that maps to score 0 (default: 2 years)
    time_range = 63072000,
  },

  -- Number of distinct highlight levels (more = smoother gradient)
  levels = 16,

  -- Automatically attach to buffers on BufReadPost / BufWritePost
  auto_attach = true,

  -- Filetypes to skip
  exclude_filetypes = { "help", "terminal", "NvimTree", ... },
})
```

## Commands

| Command           | Description                                       |
|-------------------|---------------------------------------------------|
| `:HotlineRefresh` | Re-score and re-highlight the current buffer      |
| `:HotlineToggle`  | Toggle highlights on/off for the current buffer   |

## API

```lua
local hotline = require('hotline')

hotline.attach(bufnr)   -- highlight a buffer (default: current)
hotline.detach(bufnr)   -- remove highlights from a buffer
hotline.refresh(bufnr)  -- re-score and re-highlight a buffer
```

## How it works

**Recency** — runs `git blame` to find the timestamp of the last commit that touched each line, then applies exponential decay (half-life: 7 days).

**Frequency** — parses `git log -p` to simulate the file's entire edit history and counts how many logical edits have touched each current line. This is asynchronous and cached per write.

**Frecency** — averages the normalised recency and frequency scores.

Colors are interpolated through a three-stop gradient (min → mid → max) and applied as line background highlights via Neovim extmarks.

## Performance

- `recency` mode: single fast `git blame` call, synchronous.
- `frequency` / `frecency` modes: one `git log -p` call per buffer load/write, run asynchronously so the UI never blocks. Large repos with long histories may take a moment on first load.
