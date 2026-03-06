local M = {}

local config = require("hotline.config")
local git = require("hotline.git")
local score = require("hotline.score")
local color = require("hotline.color")

local cfg = config.defaults
local hl_groups = nil
local ns = vim.api.nvim_create_namespace("hotline")

local function is_excluded(bufnr)
  local bt = vim.bo[bufnr].buftype
  if bt ~= "" and bt ~= "acwrite" then
    return true
  end
  if vim.bo[bufnr].binary then
    return true
  end
  local ft = vim.bo[bufnr].filetype
  for _, ex in ipairs(cfg.exclude_filetypes) do
    if ft == ex then
      return true
    end
  end
  return false
end

local function apply_highlights(bufnr, scores)
  vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
  local line_count = vim.api.nvim_buf_line_count(bufnr)
  for line_num, s in pairs(scores) do
    local row = line_num - 1 -- nvim extmarks are 0-indexed
    if row >= 0 and row < line_count then
      vim.api.nvim_buf_set_extmark(bufnr, ns, row, 0, {
        line_hl_group = color.score_to_group(s, hl_groups),
        priority = 100,
      })
    end
  end
end

local function refresh(bufnr)
  if is_excluded(bufnr) then
    return
  end

  local filepath = vim.api.nvim_buf_get_name(bufnr)
  if filepath == "" then
    return
  end

  -- git blame is fast; run it synchronously
  local blame_data = git.blame(filepath)
  if not blame_data or next(blame_data) == nil then
    return
  end

  if cfg.method == "recency" then
    -- Recency only: no need for full git log
    local scores = score.compute(blame_data, nil, cfg.method, cfg.relativity)
    apply_highlights(bufnr, scores)
  else
    -- frequency / frecency: parse full git history asynchronously
    local cwd = vim.fn.fnamemodify(filepath, ":h")
    vim.system(
      {
        "git",
        "log",
        "--follow",
        "-p",
        "--unified=0",
        "--reverse",
        "--diff-filter=AM",
        "--format=COMMIT %H %at",
        "--",
        filepath,
      },
      { cwd = cwd, text = true },
      function(result)
        vim.schedule(function()
          if not vim.api.nvim_buf_is_valid(bufnr) then
            return
          end
          local touches = nil
          if result.code == 0 and result.stdout then
            touches = git.parse_frequency(result.stdout)
          end
          local scores = score.compute(blame_data, touches, cfg.method, cfg.relativity)
          apply_highlights(bufnr, scores)
        end)
      end
    )
  end
end

-- Re-run scoring and re-apply highlights for the given buffer (default: current).
function M.refresh(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  refresh(bufnr)
end

-- Apply highlights to a buffer (alias for refresh).
function M.attach(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  refresh(bufnr)
end

-- Remove all hotline highlights from a buffer.
function M.detach(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
end

-- Configure and enable hotline.
-- opts: any subset of the defaults in lua/hotline/config.lua
function M.setup(opts)
  vim.g.hotline_setup_done = true
  cfg = config.merge(opts)
  hl_groups = color.setup_highlights(cfg.scale, cfg.levels)

  local augroup = vim.api.nvim_create_augroup("Hotline", { clear = true })

  if cfg.auto_attach then
    vim.api.nvim_create_autocmd({ "BufReadPost", "BufWritePost" }, {
      group = augroup,
      callback = function(ev)
        refresh(ev.buf)
      end,
    })
  end

  -- Recreate highlight groups whenever the colorscheme changes
  vim.api.nvim_create_autocmd("ColorScheme", {
    group = augroup,
    callback = function()
      hl_groups = color.setup_highlights(cfg.scale, cfg.levels)
      -- Re-apply to any buffer already highlighted
      for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_loaded(bufnr) then
          local marks = vim.api.nvim_buf_get_extmarks(bufnr, ns, 0, -1, { limit = 1 })
          if #marks > 0 then
            refresh(bufnr)
          end
        end
      end
    end,
  })

  vim.api.nvim_create_user_command("HotlineRefresh", function()
    M.refresh()
  end, { desc = "Refresh hotline highlights for current buffer" })

  vim.api.nvim_create_user_command("HotlineToggle", function()
    local bufnr = vim.api.nvim_get_current_buf()
    local marks = vim.api.nvim_buf_get_extmarks(bufnr, ns, 0, -1, { limit = 1 })
    if #marks > 0 then
      M.detach(bufnr)
    else
      M.attach(bufnr)
    end
  end, { desc = "Toggle hotline highlights for current buffer" })
end

return M
