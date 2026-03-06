-- Loaded automatically by Neovim's runtime when hotline.nvim is installed.
-- Auto-initialises with defaults if the user never calls require('hotline').setup().

if vim.g.loaded_hotline then
  return
end
vim.g.loaded_hotline = true

local function maybe_auto_setup()
  if not vim.g.hotline_setup_done then
    require("hotline").setup()
  end
end

-- vim.v.vim_did_enter is 1 after VimEnter has fired.
-- Handle both eager loading (normal start) and lazy loading (loaded mid-session).
if vim.v.vim_did_enter == 1 then
  maybe_auto_setup()
else
  vim.api.nvim_create_autocmd("VimEnter", {
    once = true,
    callback = maybe_auto_setup,
  })
end
