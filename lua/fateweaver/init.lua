local M = {}

local changes = require("fateweaver.changes")
local config = require("fateweaver.config")

function M.setup(opts)
  opts = opts or {}

  config.setup(opts)

  changes.setup()
end

function M.get_recent_changes_as_diff()
  return M.changes.get_all_diffs()
end

return M
