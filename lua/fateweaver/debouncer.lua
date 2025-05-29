---@type table<any, number>return M
local timer_map = {}

---@class fateweaver.Debouncer
---@field debounce fun(time_ms: integer, key: any, callback: function): nil
---@field cancel fun(key: any): nil
local M = {}

---@param ms number milliseconds to wait before executing the callback
---@param key any unique identifier for this timer
---@param callback function function to execute after debounce period
---@return number timer id
function M.debounce(ms, key, callback)
  if timer_map[key] then
    vim.fn.timer_stop(timer_map[key])
  end

  timer_map[key] = vim.fn.timer_start(ms, function()
    callback()
    timer_map[key] = nil
  end)

  return timer_map[key]
end

---@param key any the key used to identify the timer to cancel
function M.cancel(key)
  if timer_map[key] then
    vim.fn.timer_stop(timer_map[key])
    timer_map[key] = nil
  end
end

return M
