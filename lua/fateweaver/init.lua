local M = {}

local changes = require("fateweaver.changes")
local zeta_client = require("fateweaver.zeta_client")
local config = require("fateweaver.config")

function M.setup(opts)
  opts = opts or {}

  config.setup(opts)

  changes.setup()
end

function M.get_all_diffs()
  return changes.get_all_diffs()
end

function M.test()
  zeta_client.request_completion("", "", function(res)

  end)
end

return M
