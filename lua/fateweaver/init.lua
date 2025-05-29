---@type fateweaver.Config
local config = require("fateweaver.config")
---@type fateweaver.Listeners
local listeners = require("fateweaver.listeners")
---@type fateweaver.CompletionEngine
local completion_engine = require("fateweaver.completion_engine")
---@type fateweaver.UI
local ui = require("fateweaver.ui")
---@type fateweaver.Client
local client = require("fateweaver.zeta.client")

---@type table
local M = {}

---Sets up the Fateweaver plugin with the provided options
---@param opts Config Configuration options
function M.setup(opts)
  opts = opts or {}

  config.setup(opts)

  completion_engine.setup(ui, client)

  listeners.setup()

  -- TODO: Add to config
  vim.keymap.set('i', '<C-y>', function() require("fateweaver.completion_engine").accept_completion() end,
    { silent = true })
end

---Requests completions for the current buffer
---@return nil
function M.request_completion()
  ---@type number
  local bufnr = vim.api.nvim_get_current_buf()

  completion_engine.propose_completions(bufnr)
end

return M
