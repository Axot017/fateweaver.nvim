local M = {}

local _default_config = {
  log_level = "ERROR",
  max_changes_in_context = 3,
  max_tracked_buffers = 5,
  endpoint = "http://localhost:11434/api/generate",
  context_offset = 25,
  debounce_ms = 250
}

local _config = _default_config


M.setup = function(new_config)
  local c = new_config or {}

  _config = vim.tbl_extend("force", _default_config, c)
end

M.get = function()
  return _config
end

return M
