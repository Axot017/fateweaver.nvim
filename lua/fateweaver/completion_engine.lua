---@type fateweaver.Changes
local changes = require("fateweaver.changes")
---@type fateweaver.Logger
local logger = require("fateweaver.logger")
---@type fateweaver.Debouncer
local debouncer = require("fateweaver.debouncer")
---@type fateweaver.Config
local config = require("fateweaver.config")

---@class fateweaver.Client
---@field request_completion fun(bufnr: integer, changes: Change[], callback: fun(completions: Completion[])): nil
---@field cancel_request fun(): nil

---@class fateweaver.UI
---@field show_inline_completions fun(bufnr: integer, lines: string[]): nil
---@field show_addition fun(bufnr: integer, position: integer, lines: string[]): nil
---@field show_deletion fun(bufnr: integer, from: integer, to: integer): nil
---@field show_diff fun(bufnr: integer, from: integer, to: integer, lines: string[]): nil
---@field clear fun(bufnr: integer): nil

---@class Completion
---@field find string
---@field replace string

local accepted_completions = 0

local active_bufnr = -1
---@type Completion[]
local active_completions = {}

---@class fateweaver.CompletionEngine
---@field on_insert fun(bufnr: integer): nil
---@field clear fun(): nil
---@field set_active_buffer fun(bufnr: integer): nil
---@field setup fun(ui: fateweaver.UI, client: fateweaver.Client)
---@field request_completion fun(bufnr: integer, additional_change: Change|nil)
local M = {}

---@param ui fateweaver.UI
---@param client fateweaver.Client
---@return nil
function M.setup(ui, client)
  M.ui = ui
  M.client = client
end

---@return nil
function M.accept_completion()
  local completion_idx = 1
  local completion = active_completions[completion_idx]
  if not completion then
    logger.info("No completion to accept")
    return
  end

  logger.debug("Completion accepted")

  M.ui.clear(active_bufnr)

  accepted_completions = accepted_completions + 1
  table.remove(active_completions, 1)

  -- Apply completion
end

---@param bufnr integer
---@param additional_change Change
---@return nil
function M.request_completion(bufnr, additional_change)
  local previous_changes = changes.get_buffer_diffs(bufnr)
  if additional_change then
    table.insert(previous_changes, additional_change)
  end


  M.client.request_completion(bufnr, previous_changes, function(completions)
    if active_bufnr ~= bufnr then
      return
    end

    -- Propose completions
  end)
end

---@param bufnr integer
---@return nil
function M.on_insert(bufnr)
  local is_after_completion_accept = accepted_completions ~= 0

  local next_completion = active_completions[1]
  if next_completion ~= nil and next_completion.bufnr == active_bufnr and is_after_completion_accept then
    accepted_completions = accepted_completions - 1
    -- Show the next completion
    return
  end

  if is_after_completion_accept then
    accepted_completions = accepted_completions - 1
  end

  M.clear()

  active_bufnr = bufnr
  local ms = config.get().debounce_ms

  debouncer.debounce(ms, active_bufnr, function()
    local additional_change = changes.calculate_change(bufnr)
    M.request_completion(bufnr, additional_change)
  end)
end

---@return nil
function M.clear()
  M.client.cancel_request()
  if active_bufnr ~= nil then
    debouncer.cancel(active_bufnr)
    if #active_completions ~= 0 then
      M.ui.clear(active_bufnr)
      active_completions = {}
    end
  end
end

---@param bufnr integer
---@return nil
function M.set_active_buffer(bufnr)
  active_bufnr = bufnr
  changes.track_buffer(bufnr)
end

return M
