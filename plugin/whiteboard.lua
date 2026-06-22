if vim.g.loaded_whiteboard == 1 then
  return
end
vim.g.loaded_whiteboard = 1

vim.api.nvim_create_user_command('WhiteboardOpen', function()
  require('whiteboard-nvim').open()
end, { desc = 'Open the whiteboard for the current git repo in a browser' })

vim.api.nvim_create_user_command('WhiteboardAddFile', function()
  require('whiteboard-nvim').add_file()
end, { desc = 'Pin the current file to the whiteboard' })

vim.api.nvim_create_user_command('WhiteboardAddSnippet', function()
  require('whiteboard-nvim').add_snippet()
end, {
  -- Works as :'<,'>WhiteboardAddSnippet — reads '< '> marks set by visual mode
  range = true,
  desc  = 'Pin the selected code snippet to the whiteboard',
})

vim.api.nvim_create_user_command('WhiteboardClose', function()
  require('whiteboard-nvim').close()
end, { desc = 'Stop the whiteboard server' })

vim.api.nvim_create_user_command('WhiteboardReset', function()
  require('whiteboard-nvim').reset()
end, { desc = 'Clear the whiteboard for the current git repo' })
