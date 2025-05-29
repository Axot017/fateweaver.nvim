---@type fateweaver.Logger
local logger = require("fateweaver.logger")

local M = {}

---@type integer Namespace ID for virtual text and virtual lines
local ns_id = vim.api.nvim_create_namespace("fateweaver_completions")

---Clears all inline completions from the buffer
---@param bufnr integer The buffer number to clear completions from
---@return nil
function M.clear(bufnr)
  logger.debug("ui.clean")
  vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)
end

---Shows inline completions in the buffer
---@param bufnr integer The buffer number to show completions in
---@param cursor_pos integer[] Array containing [line, column] of cursor position
---@param proposed_lines string[] Array of completion lines to display
---@param diff integer[] Array containing [original_start, original_len, proposed_start, proposed_len] difference information
---@return nil
function M.show_inline_completions(bufnr, cursor_pos, proposed_lines, diff)
  logger.debug("ui.show_inline_completions")
  M.clear(bufnr)

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

---Shows completions as diff with highlighted changes
---@param bufnr integer The buffer number to show completions in
---@param proposed_lines string[] Array of completion lines to display
---@param diff integer[] Array containing [original_start, original_len, proposed_start, proposed_len] difference information
---@return nil
function M.show_diff_completions(bufnr, proposed_lines, diff)
  logger.debug("ui.show_diff_completions")
  M.clear(bufnr)

  local buffer_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

  local original_start = diff[1]
  local original_len = diff[2]
  local proposed_start = diff[3]
  local proposed_len = diff[4]

  local original_end = original_start + original_len - 1

  local line = buffer_lines[original_end]

  -- Highlight existing lines with red background
  vim.api.nvim_buf_set_extmark(bufnr, ns_id, original_start - 1, 0, {
    line_hl_group = "DiffDelete",
    end_row = original_end - 1,
    end_col = #line - 1
  })

  -- Show proposed lines as virtual text with green background
  local virtual_lines = {}
  for i = proposed_start, proposed_start + proposed_len - 1 do
    if i <= #proposed_lines then
      table.insert(virtual_lines, { { proposed_lines[i], "DiffAdd" } }) -- Green background for proposed lines
    end
  end

  -- Add virtual lines after the last existing line
  if #virtual_lines > 0 then
    vim.api.nvim_buf_set_extmark(bufnr, ns_id, original_end - 1, 0, {
      virt_lines = virtual_lines,
      virt_lines_above = false,
    })
  end
end

return M
