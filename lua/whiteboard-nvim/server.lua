-- whiteboard.server — Node.js server lifecycle.

local M = {}

-- Returns the absolute path to the server/ directory, regardless of cwd.
local function server_dir()
  local src = debug.getinfo(1, 'S').source:sub(2)
  return vim.fn.fnamemodify(src, ':p:h:h:h') .. '/server'
end

-- Start the Node.js server for repo_root.
-- callbacks = { on_ready(port), on_open(path, line) }
-- Returns the job id, or nil on failure.
function M.start(repo_root, callbacks)
  local state    = require('whiteboard-nvim.state')
  local data_dir = vim.fn.stdpath('data')
  local entry    = server_dir() .. '/index.js'
  local cfg      = require('whiteboard-nvim.config').options

  local job_id = vim.fn.jobstart({
    'node', entry,
    '--repo',       repo_root,
    '--data-dir',   data_dir,
    '--port',       tostring(cfg.server.port),
    '--background', cfg.ui.background,
  }, {
    -- stdout_buffered = false is critical: we stream stdout to capture the
    -- LISTENING:<port> sentinel as soon as the server emits it.
    stdout_buffered = false,

    on_stdout = function(_, lines)
      for _, line in ipairs(lines) do
        -- Server-ready sentinel
        local port = line:match('^LISTENING:(%d+)$')
        if port and state.session then
          state.session.port    = tonumber(port)
          state.session.running = true
          vim.schedule(function() callbacks.on_ready(tonumber(port)) end)
        end

        -- Browser-initiated open command: CMD:<json>
        local cmd_json = line:match('^CMD:(.+)$')
        if cmd_json and callbacks.on_open then
          local ok, data = pcall(vim.fn.json_decode, cmd_json)
          if ok and data and data.type == 'open' then
            vim.schedule(function()
              callbacks.on_open(data.path, data.line or 0)
            end)
          end
        end
      end
    end,

    on_stderr = function(_, lines)
      for _, line in ipairs(lines) do
        if line ~= '' then
          vim.schedule(function()
            vim.notify('whiteboard [server]: ' .. line, vim.log.levels.WARN)
          end)
        end
      end
    end,

    on_exit = function()
      vim.schedule(function()
        if state.session then
          state.session.running = false
        end
      end)
    end,
  })

  if job_id <= 0 then
    vim.notify(
      'whiteboard: failed to start server — is `node` on your PATH?',
      vim.log.levels.ERROR
    )
    return nil
  end

  return job_id
end

function M.stop()
  local state = require('whiteboard-nvim.state')
  if state.session and state.session.server_job then
    vim.fn.jobstop(state.session.server_job)
    state.session.server_job = nil
    state.session.running    = false
  end
end

return M
