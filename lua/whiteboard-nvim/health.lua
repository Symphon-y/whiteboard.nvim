-- whiteboard.health — :checkhealth whiteboard

local M = {}

local health  = vim.health or {}
local h_start = health.start  or health.report_start
local h_ok    = health.ok     or health.report_ok
local h_warn  = health.warn   or health.report_warn
local h_error = health.error  or health.report_error

local function plugin_root()
  local src = debug.getinfo(1, 'S').source:sub(2)
  return vim.fn.fnamemodify(src, ':p:h:h:h')
end

function M.check()
  local root = plugin_root()

  h_start('whiteboard: Node.js runtime')
  if vim.fn.executable('node') == 1 then
    local v = vim.fn.system('node --version'):gsub('%s+', '')
    h_ok('node found: ' .. v)
  else
    h_error('`node` not found', {
      'Install Node.js >= 18 from https://nodejs.org',
      'Ensure `node` is on the PATH where Neovim is launched',
    })
  end

  h_start('whiteboard: server dependencies')
  local nm = root .. '/server/node_modules'
  if vim.fn.isdirectory(nm) == 1 then
    h_ok('server/node_modules present')
  else
    h_error('server/node_modules missing', {
      'Run: cd ' .. root .. '/server && npm install',
    })
  end

  h_start('whiteboard: pre-built frontend')
  local app_js = root .. '/server/public/app.js'
  if vim.fn.filereadable(app_js) == 1 then
    h_ok('server/public/app.js present')
  else
    h_error('server/public/app.js missing (pre-built Excalidraw bundle)', {
      'Run: cd ' .. root .. '/server && npm install && npm run build',
    })
  end

  h_start('whiteboard: curl (HTTP client)')
  if vim.fn.executable('curl') == 1 then
    h_ok('curl found')
  else
    h_warn('curl not found', {
      'curl is used to POST elements to the server',
      'Install curl or ensure it is on your PATH',
    })
  end

  h_start('whiteboard: browser launcher')
  local launcher
  if vim.fn.has('mac') == 1 then
    launcher = 'open'
  elseif vim.fn.has('win32') == 1 or vim.fn.has('win64') == 1 then
    launcher = 'cmd'
  else
    launcher = 'xdg-open'
  end
  if vim.fn.executable(launcher) == 1 then
    h_ok('browser launcher available: ' .. launcher)
  else
    h_warn('browser launcher not found: ' .. launcher)
  end

  h_start('whiteboard: boards directory')
  local board_dir = vim.fn.stdpath('data') .. '/whiteboard/boards'
  local ok = pcall(function() vim.fn.mkdir(board_dir, 'p') end)
  if ok and vim.fn.isdirectory(board_dir) == 1 then
    h_ok('boards directory: ' .. board_dir)
  else
    h_warn('boards directory not writable: ' .. board_dir, {
      'Check permissions on ' .. vim.fn.stdpath('data'),
    })
  end
end

return M
