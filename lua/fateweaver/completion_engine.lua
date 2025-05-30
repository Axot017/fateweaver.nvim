---@type fateweaver.Changes
local changes = require("fateweaver.changes")
---@type fateweaver.Logger
local logger = require("fateweaver.logger")
---@type fateweaver.Debouncer
local debouncer = require("fateweaver.debouncer")
---@type fateweaver.Config
local config = require("fateweaver.config")

---@class fateweaver.Client
---@field request_completion fun(bufnr: integer, editable_region: EditableRegion, cursor_pos: integer[], changes: Change[], callback: fun(completions: string[])): nil
---@field cancel_request fun(): nil

---@class fateweaver.UI
---@field show_inline_completions fun(completion: Completion): nil
---@field show_diff_completions fun(completion: Completion): nil
---@field clear fun(bufnr: integer): nil

---@class EditableRegion
---@field start_line number The starting line number of the editable region
---@field end_line number The ending line number of the editable region

---@class Completion
---@field lines_to_replace string[]
---@field diff integer[]
---@field bufnr integer
---@field type string

---@class CompletionChain
---@field completion Completion
---@field next CompletionChain|nil

---@param current_lines string[]
---@param proposed_lines string[]
---@return integer[][]
local function calculate_diffs(current_lines, proposed_lines)
  local current_lines_str = table.concat(current_lines, "\n")
  logger.debug("Current lines:\n" .. current_lines_str)
  local proposed_lines_str = table.concat(proposed_lines, "\n")
  logger.debug("Proposed lines:\n" .. proposed_lines_str)

  local diff = vim.diff(current_lines_str, proposed_lines_str, {
    result_type = "indices"
  })

  if diff == nil or #diff == 0 then
    logger.debug("No diff")
    return {}
  end

  logger.debug("Diff:\n" .. vim.inspect(diff))

  ---@diagnostic disable-next-line: return-type-mismatch
  return diff
end

---@param proposed_lines string[]
---@param diff integer[][]
---@return string[]
local function added_lines(proposed_lines, diff)
  local proposed_start = diff[3]
  local proposed_len = diff[4]
  local result = {}
  for i = proposed_start, proposed_start + proposed_len - 1 do
    table.insert(result, proposed_lines[i])
  end

  return result
end

---@param editable_region EditableRegion
---@param diff integer[][]
---@return integer[][]
local function adjust_diff(editable_region, diff)
  local offset = editable_region.start_line - 1

  logger.debug("Original diff: " .. vim.inspect(diff))
  diff[1] = diff[1] + offset
  diff[3] = diff[3] + offset
  logger.debug("Adjusted diff: " .. vim.inspect(diff))

  return diff
end

-- TODO: Add to config
---@param cursor_row integer
---@return EditableRegion
local function get_editable_region(cursor_row)
  local win_top = vim.fn.line('w0')
  local win_bottom = vim.fn.line('w$')
  local editable_region_top = cursor_row - 10
  if editable_region_top < win_top then
    editable_region_top = win_top
  end
  local editable_region_bottom = cursor_row + 10
  if editable_region_bottom > win_bottom then
    editable_region_bottom = win_bottom
  end


  local editable_region = { start_line = editable_region_top, end_line = editable_region_bottom }
  return editable_region
end

---@param proposed_completion CompletionChain
---@return nil
local function apply_completion(proposed_completion)
  local new_lines = proposed_completion.completion.lines_to_replace
  local diff = proposed_completion.completion.diff
  local original_start = diff[1]
  local original_len = diff[2]
  local proposed_start = diff[3]
  local proposed_len = diff[4]

  local insert_start = original_start - 1
  local insert_end = original_start + original_len - 1

  if original_len == 0 then
    insert_start = insert_start + 1
    insert_end = insert_start
  end

  vim.api.nvim_buf_set_lines(
    proposed_completion.completion.bufnr,
    insert_start,
    insert_end,
    false,
    new_lines
  )

  local cursor_target_line = proposed_start + proposed_len - 1
  if new_lines == nil or #new_lines == 0 then
    return
  end
  local last_line_len = #new_lines[#new_lines]

  vim.api.nvim_win_set_cursor(0, { cursor_target_line, last_line_len })
end

---@param bufnr integer
---@param editable_region EditableRegion
---@return string[]
local function get_editable_region_lines(bufnr, editable_region)
  local lines = vim.api.nvim_buf_get_lines(bufnr, editable_region.start_line - 1, editable_region.end_line, false)

  return lines
end

---@param bufnr integer
---@param editable_region EditableRegion
---@param diffs integer[][]
---@param proposed_lines string[]
---@return Completion[]
local function generate_completions(bufnr, editable_region, diffs, proposed_lines)
  local completions = {}
  for _, diff in ipairs(diffs) do
    local lines_to_replace = added_lines(proposed_lines, diff)
    local real_diff = adjust_diff(editable_region, diff)
    table.insert(completions, {
      lines_to_replace = lines_to_replace,
      diff = real_diff,
      bufnr = bufnr
    })
  end

  logger.debug("Completions:\n" .. vim.inspect(completions))

  return completions
end

---@param bufnr integer
---@param completions Completion[]
---@return Completion[]
local function sort_completions(bufnr, completions)
  local current_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

  local cursor_position = vim.api.nvim_win_get_cursor(0)
  local cursor_line = cursor_position[1]
  local cursor_col = cursor_position[2]

  local inline_completion = {}
  local diff_completions = {}

  for _, completion in ipairs(completions) do
    local diff = completion.diff

    local original_start = diff[1]
    local original_len = diff[2]
    local proposed_len = diff[4]

    if original_start == cursor_line and original_len == 1 and proposed_len > 0 then
      local original = current_lines[original_start]
      local proposed = completion.lines_to_replace[1]

      for i = 1, cursor_col do
        local o = original:sub(i, i)
        local p = proposed:sub(i, i)
        if o ~= p then
          goto diff
        end
      end

      completion.type = "inline"
      table.insert(inline_completion, completion)
      goto continue
    end

    ::diff::
    completion.type = "diff"
    table.insert(diff_completions, completion)
    ::continue::
  end

  local result = {}
  for _, inline in ipairs(inline_completion) do
    table.insert(result, inline)
  end
  for _, diff in ipairs(diff_completions) do
    table.insert(result, diff)
  end

  logger.debug("Ordered completions:\n" .. vim.inspect(result))

  return result
end

---@param sorted_completions Completion[]
---@return CompletionChain
local function chain_from_sorted_completions(sorted_completions)
  local current = {
    completion = sorted_completions[#sorted_completions],
    next = nil,
  }
  for i = 1, #sorted_completions - 1 do
    local previous = current
    current = {
      completion = sorted_completions[#sorted_completions - i],
      next = previous,
    }
  end

  logger.debug("Completions chain:\n" .. vim.inspect(current))

  return current
end

---@param bufnr integer
---@param editable_region EditableRegion
---@param diffs integer[][]
---@param proposed_lines string[]
---@return CompletionChain
local function generate_completion_chain(bufnr, editable_region, diffs, proposed_lines)
  local completions = generate_completions(bufnr, editable_region, diffs, proposed_lines)
  completions = sort_completions(bufnr, completions)

  return chain_from_sorted_completions(completions)
end


local active_bufnr = -1
---@type CompletionChain|nil
local active_chain = nil

---@class fateweaver.CompletionEngine
---@field on_insert fun(bufnr: integer): nil
---@field clear fun(): nil
---@field set_active_buffer fun(bufnr: integer): nil
---@field setup fun(ui: fateweaver.UI, client: fateweaver.Client)
---@field request_completion fun(bufnr: integer, additional_change: Change)
local M = {}

---@param ui fateweaver.UI
---@param client fateweaver.Client
---@return nil
function M.setup(ui, client)
  M.ui = ui
  M.client = client
end

---@param completion Completion
---@return nil
function M.show_completion(completion)
  if completion.type == "diff" then
    M.ui.show_diff_completions(completion)
  else
    M.ui.show_inline_completions(completion)
  end
end

---@param bufnr integer
---@param editable_region EditableRegion
---@param diffs integer[][]
---@param proposed_lines string[]
---@return nil
function M.start_chain(bufnr, editable_region, diffs, proposed_lines)
  local chain = generate_completion_chain(bufnr, editable_region, diffs, proposed_lines)

  active_chain = chain

  M.show_completion(chain.completion)
end

---@return nil
function M.accept_completion()
  if not active_chain then
    logger.info("No completion to accept")
    return
  end

  logger.debug("Completion accepted")

  M.ui.clear(active_chain.completion.bufnr)

  apply_completion(active_chain)

  active_chain = active_chain.next
end

---@param bufnr integer
---@param additional_change Change
---@return nil
function M.request_completion(bufnr, additional_change)
  local previous_changes = changes.get_buffer_diffs(bufnr)
  if additional_change then
    table.insert(previous_changes, additional_change)
  end
  local cursor_pos = vim.api.nvim_win_get_cursor(0)
  local editable_region = get_editable_region(cursor_pos[1])


  M.client.request_completion(bufnr, editable_region, cursor_pos, previous_changes, function(completions)
    if active_bufnr ~= bufnr then
      return
    end

    local editable_region_lines = get_editable_region_lines(bufnr, editable_region)
    local diffs = calculate_diffs(editable_region_lines, completions)

    if #diffs == 0 then
      return
    end

    M.start_chain(bufnr, editable_region, diffs, completions)
  end)
end

---@param bufnr integer
---@return nil
function M.on_insert(bufnr)
  if active_chain ~= nil and active_chain.completion.bufnr == active_bufnr then
    M.show_completion(active_chain.completion)
    return
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
  logger.debug("completion_engine.clear")
  M.client.cancel_request()
  if active_bufnr ~= nil then
    debouncer.cancel(active_bufnr)
  end
  if active_chain then
    M.ui.clear(active_chain.completion.bufnr)
    active_chain = nil
  end
end

---@param bufnr integer
---@return nil
function M.set_active_buffer(bufnr)
  active_bufnr = bufnr
  changes.track_buffer(bufnr)
end

return M
