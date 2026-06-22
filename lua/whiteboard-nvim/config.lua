local M = {}

local defaults = {
  keymaps = {
    add_file    = '<leader>wa',
    add_snippet = '<leader>ws',
    open        = '<leader>wo',
  },
  server = {
    port      = 0,
    auto_open = true,
  },
  ui = {
    card_width     = 300,
    snippet_width  = 420,
    card_height    = 120,
    snippet_height = 200,
    row_gap        = 40,
    col_gap        = 40,
    cards_per_row  = 4,
    -- Canvas background color. Defaults to a subtle off-white so white file
    -- cards are distinguishable from the canvas. Set to '#ffffff' for pure white.
    background     = '#f0f0f0',
  },
}

M.options = vim.deepcopy(defaults)

function M.setup(opts)
  M.options = vim.tbl_deep_extend('force', vim.deepcopy(defaults), opts or {})
  return M.options
end

return M
