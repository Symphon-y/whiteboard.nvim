local M = {}

M.session = nil

function M.new(repo_root)
  M.session = {
    server_job  = nil,
    port        = nil,
    repo_root   = repo_root,
    running     = false,
    board_open  = false,
  }
  return M.session
end

function M.active()
  return M.session ~= nil and M.session.running == true
end

function M.clear()
  M.session = nil
end

return M
