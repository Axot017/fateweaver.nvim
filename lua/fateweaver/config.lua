---@class Config.ContextOpts
---@field max_tracked_buffers integer Maximum number of buffers to track
---@field max_history_per_buffer integer Maximum number of changes to keep in history per buffer
---@field context_before_cursor integer Number of lines to include before cursor for context
---@field context_after_cursor integer Number of lines to include after cursor for context
---@field editable_region_before_cursor integer Number of lines before cursor that LLM can edit
---@field editable_region_after_cursor integer Number of lines after cursor that LLM can edit

---@class Config
---@field log_level string Level of logging ("ERROR", "WARN", "INFO", "DEBUG")
---@field logger_fn fun(msg: string): nil Function used for logging
---@field context_opts Config.ContextOpts Context configuration for LLM
---@field completion_endpoint string API endpoint URL for generation
---@field api_key string|fun(): string|nil API key for the AI model or a function to retrieve it.
---@field model_name string AI model identifier to use
---@field debounce_ms integer Debounce time in milliseconds

---@class fateweaver.Config
---@field setup fun(Config): nil
---@field get fun(): Config
local M = {}

local _default_config = {
  log_level = "ERROR",
  logger_fn = vim.notify,
  context_opts = {
    max_tracked_buffers = 5,
    max_history_per_buffer = 3,
    context_before_cursor = 30,
    context_after_cursor = 50,
    editable_region_before_cursor = 10,
    editable_region_after_cursor = 30
  },
  completion_endpoint = "http://localhost:11434/v1/completions",
  api_key = nil,
  model_name = "hf.co/bartowski/zed-industries_zeta-GGUF:Q4_K_M",
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
