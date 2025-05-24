local config = require("fateweaver.config")
local listeners = require("fateweaver.listeners")
local completer = require("fateweaver.completer")

local M = {}

function M.setup(opts)
  opts = opts or {}

  config.setup(opts)

  listeners.setup()
end

function M.request_completion()
  local bufnr = vim.api.nvim_get_current_buf()

  completer.propose_completions(bufnr)
end

return M
