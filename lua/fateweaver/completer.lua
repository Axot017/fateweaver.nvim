local changes = require("fateweaver.changes")
local client = require("fateweaver.client")
local logger = require("fateweaver.logger")

local function get_editable_region()
  local win_top = vim.fn.line('w0')
  local win_bottom = vim.fn.line('w$')
  local editable_region = { start_line = win_top, end_line = win_bottom }
  return editable_region
end

local function get_editable_region_lines(bufnr, editable_region)
  local lines = vim.api.nvim_buf_get_lines(bufnr, editable_region.start_line - 1, editable_region.end_line, false)

  return lines
end

local request_bufnr = -1
local ns_id = vim.api.nvim_create_namespace("fateweaver_completions")

local function show_inline_completions(bufnr, cursor_pos, proposed_lines, diff)
  local cursor_line = cursor_pos[1]
  local cursor_col = cursor_pos[2]
  local proposed_start = diff[3]
  local proposed_len = diff[4]

  local first_proposed_line = proposed_lines[proposed_start]
  local first_line = first_proposed_line:sub(cursor_col + 1, #first_proposed_line)
  vim.api.nvim_buf_set_extmark(bufnr, ns_id, cursor_line - 1, cursor_col, {
    virt_text = { { first_line, "Comment" } },
    virt_text_pos = "overlay",
  })
  if #proposed_lines > 1 then
    local result_lines = {}
    for i = proposed_start + 1, proposed_start + proposed_len - 1 do
      table.insert(result_lines, { { proposed_lines[i], "Comment" } })
    end
    vim.api.nvim_buf_set_extmark(bufnr, ns_id, cursor_line - 1, 0, {
      virt_lines = result_lines,
      virt_text_pos = "overlay",
    })
  end
end

local function show_completions(bufnr, editable_region, diffs, current_lines, proposed_lines)
  vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)

  local cursor_position = vim.api.nvim_win_get_cursor(0)
  local cursor_line = cursor_position[1]
  local cursor_col = cursor_position[2]

  local cursor_line_in_region = cursor_line - editable_region.start_line + 1

  logger.debug("Cursor real line - " .. cursor_line .. " | Cursor in editable region - " .. cursor_line_in_region)
  for _, diff in ipairs(diffs) do
    local original_start = diff[1]
    local original_len = diff[2]
    local proposed_start = diff[3]
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
      show_inline_completions(bufnr, cursor_position, proposed_lines, diff)

      return
    end
  end

  ::diff::

  logger.debug("Showing diff as as git diff")
end

local M = {}

function M.propose_completions(bufnr, additional_diff)
  request_bufnr = bufnr
  local diffs = changes.get_buffer_diffs(bufnr)
  if additional_diff then
    table.insert(diffs, additional_diff)
  end
  local cursor_pos = vim.api.nvim_win_get_cursor(0)
  local editable_region = get_editable_region()


  client.request_completion(bufnr, editable_region, cursor_pos, diffs, function(completions)
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

    show_completions(bufnr, editable_region, diff, editable_region_lines, completions)
  end)
end

function M.clear()
  vim.api.nvim_buf_clear_namespace(request_bufnr, ns_id, 0, -1)
end

return M
