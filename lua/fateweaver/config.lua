local M = {}

local _default_config = {
  log_level = "ERROR",
  max_changes_in_context = 10,
  max_tracked_buffers = 10,
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
