local config = require("fateweaver.config")
local listeners = require("fateweaver.listeners")
local completer = require("fateweaver.completer")

---@type table
local M = {}

---Sets up the Fateweaver plugin with the provided options
---@param opts Config Configuration options
function M.setup(opts)
  opts = opts or {}

  config.setup(opts)

  listeners.setup()

  vim.keymap.set('i', '<C-y>', function() require("fateweaver.completer").accept_completion() end, { silent = true })
end

---Requests completions for the current buffer
---@return nil
function M.request_completion()
  ---@type number
  local bufnr = vim.api.nvim_get_current_buf()

  completer.propose_completions(bufnr)
end

return M
