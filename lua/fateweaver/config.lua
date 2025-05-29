---@class Config
---@field log_level string Level of logging ("ERROR", "WARN", "INFO", "DEBUG")
---@field logger_fn fun(msg: string): nil Function used for logging
---@field max_changes_in_context integer Maximum number of changes to keep in context
---@field max_tracked_buffers integer Maximum number of buffers to track
---@field endpoint string API endpoint URL for generation
---@field model string AI model identifier to use
---@field context_offset integer Number of lines to include before/after for context
---@field debounce_ms integer Debounce time in milliseconds

local M = {}

---@type Config
local _default_config = {
  log_level = "ERROR",
  logger_fn = vim.notify,
  max_changes_in_context = 3,
  max_tracked_buffers = 5,
  endpoint = "http://localhost:11434/api/generate",
  model = "hf.co/bartowski/zed-industries_zeta-GGUF:Q4_K_M",
  context_offset = 25,
  debounce_ms = 1000
}

---@type Config
local _config = _default_config

---@param new_config? Config
---@return nil
M.setup = function(new_config)
  local c = new_config or {}

  _config = vim.tbl_extend("force", _default_config, c)
end

---@return Config
M.get = function()
  return _config
end

return M
