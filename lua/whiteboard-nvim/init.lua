local M = {}

-- Ensure the server is running for the current repo.
-- Calls cb(port) once ready; cb is called via vim.schedule.
local function ensure_server(cb)
  local state = require('whiteboard-nvim.state')

  if state.active() then
    vim.schedule(function() cb(state.session.port) end)
    return
  end

  require('whiteboard-nvim.repo').root(function(root, err)
    if err or not root then
      vim.notify('whiteboard: ' .. (err or 'could not find git repo'), vim.log.levels.WARN)
      return
    end

    state.new(root)

    local job_id = require('whiteboard-nvim.server').start(root, function(port)
      cb(port)
    end)

    if job_id then
      state.session.server_job = job_id
    else
      state.clear()
    end
  end)
end

local function maybe_open_browser(port)
  local state = require('whiteboard-nvim.state')
  local cfg   = require('whiteboard-nvim.config').options
  if cfg.server.auto_open and not state.session.board_open then
    require('whiteboard-nvim.browser').open('http://127.0.0.1:' .. port)
    state.session.board_open = true
  end
end

function M.setup(opts)
  require('whiteboard-nvim.config').setup(opts)
  require('whiteboard-nvim.highlights').setup()

  local cfg = require('whiteboard-nvim.config').options

  if cfg.keymaps.open and cfg.keymaps.open ~= '' then
    vim.keymap.set('n', cfg.keymaps.open, function() M.open() end,
      { desc = 'whiteboard: open board in browser' })
  end

  if cfg.keymaps.add_file and cfg.keymaps.add_file ~= '' then
    vim.keymap.set('n', cfg.keymaps.add_file, function() M.add_file() end,
      { desc = 'whiteboard: pin current file to board' })
  end

  if cfg.keymaps.add_snippet and cfg.keymaps.add_snippet ~= '' then
    vim.keymap.set('v', cfg.keymaps.add_snippet, function()
      -- Exit visual mode so '< '> marks are committed before we read them.
      local esc = vim.api.nvim_replace_termcodes('<Esc>', true, false, true)
      vim.api.nvim_feedkeys(esc, 'x', false)
      M.add_snippet()
    end, { desc = 'whiteboard: pin selected code to board' })
  end
end

function M.open()
  ensure_server(function(port)
    require('whiteboard-nvim.browser').open('http://127.0.0.1:' .. port)
    require('whiteboard-nvim.state').session.board_open = true
    vim.notify('whiteboard: http://127.0.0.1:' .. port, vim.log.levels.INFO)
  end)
end

function M.add_file()
  local abs_path = vim.api.nvim_buf_get_name(0)
  if abs_path == '' then
    vim.notify('whiteboard: no file in current buffer', vim.log.levels.WARN)
    return
  end

  ensure_server(function(port)
    local state    = require('whiteboard-nvim.state')
    local repo     = require('whiteboard-nvim.repo')
    local filename = vim.fn.fnamemodify(abs_path, ':t')
    local rel_path = repo.relative_path(state.session.repo_root, abs_path)

    local elements = require('whiteboard-nvim.board').file_card({
      filename = filename,
      rel_path = rel_path,
    })

    require('whiteboard-nvim.client').add_elements(port, elements)
    maybe_open_browser(port)
  end)
end

function M.add_snippet()
  local abs_path = vim.api.nvim_buf_get_name(0)
  if abs_path == '' then
    vim.notify('whiteboard: no file in current buffer', vim.log.levels.WARN)
    return
  end

  local start_line = vim.fn.getpos("'<")[2]
  local end_line   = vim.fn.getpos("'>")[2]

  if start_line == 0 and end_line == 0 then
    vim.notify('whiteboard: no visual selection', vim.log.levels.WARN)
    return
  end

  local lines    = vim.api.nvim_buf_get_lines(0, start_line - 1, end_line, false)
  local filename = vim.fn.fnamemodify(abs_path, ':t')

  ensure_server(function(port)
    local state    = require('whiteboard-nvim.state')
    local repo     = require('whiteboard-nvim.repo')
    local rel_path = repo.relative_path(state.session.repo_root, abs_path)

    local elements = require('whiteboard-nvim.board').snippet_card({
      filename   = filename,
      rel_path   = rel_path,
      start_line = start_line,
      end_line   = end_line,
      lines      = lines,
    })

    require('whiteboard-nvim.client').add_elements(port, elements)
    maybe_open_browser(port)
  end)
end

function M.close()
  require('whiteboard-nvim.server').stop()
  require('whiteboard-nvim.state').clear()
  vim.notify('whiteboard: server stopped', vim.log.levels.INFO)
end

function M.reset()
  local state = require('whiteboard-nvim.state')

  ensure_server(function(_)
    local root       = state.session.repo_root
    local board_path = require('whiteboard-nvim.repo').board_path(root)
    vim.fn.delete(board_path)
    M.close()
    vim.notify('whiteboard: board reset', vim.log.levels.INFO)
  end)
end

return M
