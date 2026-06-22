local M = {}

local function link(name, target)
  vim.api.nvim_set_hl(0, name, { link = target, default = true })
end

function M.setup()
  link('WhiteboardStatus',      'Comment')
  link('WhiteboardStatusOk',    'DiagnosticOk')
  link('WhiteboardStatusWarn',  'DiagnosticWarn')
  link('WhiteboardStatusError', 'DiagnosticError')
end

M.setup()

vim.api.nvim_create_autocmd('ColorScheme', {
  group    = vim.api.nvim_create_augroup('WhiteboardHighlights', { clear = true }),
  callback = function() M.setup() end,
})

return M
