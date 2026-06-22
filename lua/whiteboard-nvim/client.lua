-- whiteboard.client — HTTP client for posting elements to the local server.

local M = {}

function M.add_elements(port, elements)
  local body = vim.fn.json_encode({ elements = elements })
  local url  = 'http://127.0.0.1:' .. port .. '/api/elements'

  vim.fn.jobstart({
    'curl', '-s', '-X', 'POST',
    '-H', 'Content-Type: application/json',
    '-d', body,
    url,
  }, {
    on_exit = function(_, code)
      if code ~= 0 then
        vim.schedule(function()
          vim.notify(
            'whiteboard: failed to post elements (curl exit ' .. code .. ')',
            vim.log.levels.WARN
          )
        end)
      end
    end,
  })
end

return M
