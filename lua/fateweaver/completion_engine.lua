---@class fateweaver.Changes
local changes = require("fateweaver.changes")
---@class fateweaver.Logger
local logger = require("fateweaver.logger")

---@class fateweaver.Client
---@field request_completion fun(bufnr: integer, editable_region: EditableRegion, cursor_pos: integer[], changes: Change[], callback: fun(completions: string[])): nil
---@field cancel_request fun(): nil
---
---@class fateweaver.UI
---@field show_inline_completions fun(bufnr: integer, cursor_pos: integer[], proposed_lines: string[], diff: integer[]): nil
---@field show_diff_completions fun(bufnr: integer, proposed_lines: string[], diff: integer[]): nil
---@field clear fun(bufnr: integer): nil

---@class EditableRegion
---@field start_line number The starting line number of the editable region
---@field end_line number The ending line number of the editable region

local function get_editable_region(cursor_line)
  local win_top = vim.fn.line('w0')
  local win_bottom = vim.fn.line('w$')
  local editable_region_top = cursor_line - 15
  if editable_region_top < win_top then
    editable_region_top = win_top
  end
  local editable_region_bottom = cursor_line + 15
  if editable_region_bottom > win_bottom then
    editable_region_bottom = win_bottom
  end


  local editable_region = { start_line = editable_region_top, end_line = editable_region_bottom }
  return editable_region
end

local function apply_completion(proposed_completion)
  local diff = proposed_completion.diff
  local original_start = diff[1]
  local original_len = diff[2]
  local proposed_start = diff[3]
  local proposed_len = diff[4]


  local original_end = original_start + original_len - 1

  vim.api.nvim_buf_set_lines(
    proposed_completion.bufnr,
    original_start - 1,
    original_end,
    false,
    proposed_completion.lines_to_replace
  )

  local cursor_target_line = proposed_start + proposed_len - 1
  local last_line_len = #proposed_completion.lines_to_replace[#proposed_completion.lines_to_replace]

  vim.api.nvim_win_set_cursor(0, { cursor_target_line, last_line_len })
end

local function get_editable_region_lines(bufnr, editable_region)
  local lines = vim.api.nvim_buf_get_lines(bufnr, editable_region.start_line - 1, editable_region.end_line, false)

  return lines
end

local request_bufnr = -1
local proposed_completion = nil

---@class fateweaver.CompletionEngine
---@field propose_completions fun(bufnr: integer, additional_change?: table): nil
---@field clear fun(): nil
local M = {}

---@param ui fateweaver.UI
---@param client fateweaver.Client
---@return nil
function M.setup(ui, client)
  M.ui = ui
  M.client = client
end

function M.show_completions(bufnr, editable_region, diffs, current_lines, proposed_lines)
  local cursor_position = vim.api.nvim_win_get_cursor(0)
  local cursor_line = cursor_position[1]
  local cursor_col = cursor_position[2]

  local cursor_line_in_region = cursor_line - editable_region.start_line + 1

  logger.debug("Cursor real line - " .. cursor_line .. " | Cursor in editable region - " .. cursor_line_in_region)
  for _, diff in ipairs(diffs) do
    local original_start = diff[1]
    local original_len = diff[2]
    local proposed_start = diff[3]
    local proposed_len = diff[4]
    if original_start == cursor_line_in_region and original_len == 1 then
      local original = current_lines[original_start]
      local proposed = proposed_lines[proposed_start]
      for i = 1, cursor_col do
        local o = original:sub(i, i)
        local p = proposed:sub(i, i)
        if o ~= p then
          logger.debug("Lines not equal escaping to git diff")
          goto diff
        end
      end
      logger.debug("Showing diff as virtual text behind cursor")
      M.ui.show_inline_completions(bufnr, cursor_position, proposed_lines, diff)

      local lines_to_replace = {}

      for i = proposed_start, proposed_start + proposed_len - 1 do
        table.insert(lines_to_replace, proposed_lines[i])
      end

      proposed_completion = {
        diff = diff,
        lines_to_replace = lines_to_replace,
        bufnr = bufnr
      }

      return
    end
  end

  ::diff::

  logger.debug("Showing diff as as git diff")

  local diff = diffs[1]
  M.ui.show_diff_completions(bufnr, proposed_lines, diff)

  local proposed_start = diff[3]
  local proposed_len = diff[4]
  local lines_to_replace = {}

  for i = proposed_start, proposed_start + proposed_len - 1 do
    table.insert(lines_to_replace, proposed_lines[i])
  end

  proposed_completion = {
    diff = diff,
    lines_to_replace = lines_to_replace,
    bufnr = bufnr
  }
end

function M.accept_completion()
  if not proposed_completion then
    logger.info("No completion to accept")
    return
  end

  logger.debug("Completion accepted")

  M.ui.clear(proposed_completion.bufnr)

  vim.g.fateweaver_pause_completion = true

  apply_completion(proposed_completion)
end

function M.propose_completions(bufnr, additional_diff)
  request_bufnr = bufnr
  local diffs = changes.get_buffer_diffs(bufnr)
  if additional_diff then
    table.insert(diffs, additional_diff)
  end
  local cursor_pos = vim.api.nvim_win_get_cursor(0)
  local editable_region = get_editable_region(cursor_pos[1])


  M.client.request_completion(bufnr, editable_region, cursor_pos, diffs, function(completions)
    if request_bufnr ~= bufnr then
      return
    end

    local editable_region_lines = get_editable_region_lines(bufnr, editable_region)
    local editable_region_lines_str = table.concat(editable_region_lines, "\n")
    logger.debug("Current editable region:\n" .. editable_region_lines_str)

    local completions_str = table.concat(completions, "\n")
    logger.debug("Proposed editable region:\n" .. completions_str)

    local diff = vim.diff(editable_region_lines_str, completions_str, {
      result_type = "indices"
    })

    if diff == nil or #diff == 0 then
      return
    end

    logger.debug("Diff:\n" .. vim.inspect(diff))

    M.show_completions(bufnr, editable_region, diff, editable_region_lines, completions)
  end)
end

function M.clear()
  M.client.cancel_request()
  if proposed_completion then
    M.ui.clear(proposed_completion.bufnr)
    proposed_completion = nil
  end
end

return M
