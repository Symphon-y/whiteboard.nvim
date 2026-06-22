-- whiteboard.server — Node.js server lifecycle.

local M = {}

-- Returns the absolute path to the server/ directory, regardless of cwd.
local function server_dir()
  local src = debug.getinfo(1, 'S').source:sub(2)
  return vim.fn.fnamemodify(src, ':p:h:h:h') .. '/server'
end

-- Start the Node.js server for repo_root.
-- Calls on_ready(port) once the server is listening.
-- Returns the job id, or nil on failure.
function M.start(repo_root, on_ready)
  local state    = require('whiteboard-nvim.state')
  local data_dir = vim.fn.stdpath('data')
  local entry    = server_dir() .. '/index.js'

  local job_id = vim.fn.jobstart({
    'node', entry,
    '--repo',     repo_root,
    '--data-dir', data_dir,
    '--port',     tostring(require('whiteboard-nvim.config').options.server.port),
  }, {
    -- stdout_buffered = false is critical: we stream stdout to capture the
    -- LISTENING:<port> sentinel as soon as the server emits it.
    stdout_buffered = false,

    on_stdout = function(_, lines)
      for _, line in ipairs(lines) do
        local port = line:match('^LISTENING:(%d+)$')
        if port and state.session then
          state.session.port    = tonumber(port)
          state.session.running = true
          vim.schedule(function() on_ready(tonumber(port)) end)
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
