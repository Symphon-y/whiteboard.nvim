local M = {}

-- Async: find the git root of the current working directory.
-- Calls cb(root, err) on the main thread via vim.schedule.
function M.root(cb)
  local stdout = {}
  vim.fn.jobstart({ 'git', 'rev-parse', '--show-toplevel' }, {
    stdout_buffered = true,
    on_stdout = function(_, lines)
      for _, l in ipairs(lines) do
        if l ~= '' then stdout[#stdout + 1] = l end
      end
    end,
    on_exit = function(_, code)
      vim.schedule(function()
        if code ~= 0 or #stdout == 0 then
          cb(nil, 'not a git repository')
        else
          -- Normalize to forward slashes (Neovim convention on all platforms)
          local root = stdout[1]:gsub('\\', '/'):gsub('/$', '')
          cb(root, nil)
        end
      end)
    end,
  })
end

-- Path to this repo's board JSON, stored under Neovim's data directory.
-- Never touches the repo itself — no .gitignore changes needed.
function M.board_path(repo_root)
  local data_dir  = vim.fn.stdpath('data')
  local board_dir = data_dir .. '/whiteboard/boards'
  vim.fn.mkdir(board_dir, 'p')
  local hash = vim.fn.sha256(repo_root):sub(1, 16)
  return board_dir .. '/' .. hash .. '.json'
end

-- Relative path from repo_root to abs_path, using forward slashes.
-- Returns abs_path unchanged when it is not under repo_root.
function M.relative_path(repo_root, abs_path)
  local norm_root = repo_root:gsub('\\', '/'):gsub('/$', '')
  local norm_path = abs_path:gsub('\\', '/')
  local prefix    = norm_root .. '/'
  if norm_path:sub(1, #prefix) == prefix then
    return norm_path:sub(#prefix + 1)
  end
  return norm_path
end

return M
