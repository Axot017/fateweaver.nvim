local timer_map = {}

local M = {}

function M.debounce(ms, key, callback)
  if timer_map[key] then
    vim.fn.timer_stop(timer_map[key])
  end

  timer_map[key] = vim.fn.timer_start(ms, function()
    callback()
    timer_map[key] = nil
  end)
end

return M
