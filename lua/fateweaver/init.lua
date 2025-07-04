---@type fateweaver.Config
local config = require("fateweaver.config")
---@type fateweaver.Listeners
local listeners = require("fateweaver.listeners")
---@type fateweaver.CompletionEngine
local completion_engine = require("fateweaver.completion_engine")
---@type fateweaver.UI
local ui = require("fateweaver.ui")
---@type fateweaver.Client
local client = require("fateweaver.client")
---@type fateweaver.SamplesManager
local samples_manager = require("fateweaver.samples_manager")

---@type table
local M = {}

---Sets up the Fateweaver plugin with the provided options
---@param opts Config Configuration options
function M.setup(opts)
  opts = opts or {}

  config.setup(opts)

  completion_engine.setup(ui, client, samples_manager)

  listeners.setup()
end

---Requests completions for the current buffer
---@return nil
function M.request_completion()
  ---@type number
  local bufnr = vim.api.nvim_get_current_buf()

  completion_engine.request_completion(bufnr)
end

---@return nil
function M.accept_completion()
  completion_engine.accept_completion()
end

---@return nil
function M.dismiss_completion()
  completion_engine.clear()
end

function M.save_sample()
  local bufnr = vim.api.nvim_get_current_buf()

  completion_engine.save_sample(bufnr)
end

return M
