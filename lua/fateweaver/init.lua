local changes = require("fateweaver.changes")
local client = require("fateweaver.client")
local config = require("fateweaver.config")
local listeners = require("fateweaver.listeners")
local logger = require("fateweaver.logger")
local prompt = require("fateweaver.prompt")

local M = {}

function M.setup(opts)
  opts = opts or {}

  config.setup(opts)

  listeners.setup()
end

function M.get_all_diffs()
  return changes.get_all_diffs()
end

function M.test()
  local bufnr = vim.api.nvim_get_current_buf()
  local diffs = changes.get_buffer_diffs(bufnr)
  local p = prompt.get_prompt(bufnr, diffs)

  logger.debug(p)

  client.request_completion(p, function(res)

  end)
end

return M
