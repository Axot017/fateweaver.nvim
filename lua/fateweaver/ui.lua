local M = {}

---@type integer Namespace ID for virtual text and virtual lines
local ns_id = vim.api.nvim_create_namespace("fateweaver_completions")

---Clears all inline completions from the buffer
---@param bufnr integer The buffer number to clear completions from
---@return nil
function M.clear(bufnr)
  vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)
end

---Shows inline completions in the buffer
---@param bufnr integer The buffer number to show completions in
---@param cursor_pos integer[] Array containing [line, column] of cursor position
---@param proposed_lines string[] Array of completion lines to display
---@param diff integer[] Array containing [start_line, end_line, proposed_start, proposed_len] difference information
---@return nil
function M.show_inline_completions(bufnr, cursor_pos, proposed_lines, diff)
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

return M
