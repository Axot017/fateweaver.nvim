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
---@param completion Completion
---@return nil
function M.show_inline_completions(completion)
  logger.debug("ui.show_inline_completions")

  local bufnr = completion.bufnr

  local cursor_pos = vim.api.nvim_win_get_cursor(0)

  local cursor_line = cursor_pos[1]
  local cursor_col = cursor_pos[2]

  local lines_to_replace = completion.lines_to_replace

  local first_line_to_replace = lines_to_replace[1]
  local first_line = first_line_to_replace:sub(cursor_col + 1, #first_line_to_replace)
  vim.api.nvim_buf_set_extmark(bufnr, ns_id, cursor_line - 1, cursor_col, {
    virt_text = { { first_line, "Comment" } },
    virt_text_pos = "overlay",
  })
  if #lines_to_replace > 1 then
    local result_lines = {}
    for i = 2, #lines_to_replace do
      table.insert(result_lines, { { lines_to_replace[i], "Comment" } })
    end
    logger.debug("ResultLines:\n" .. vim.inspect(result_lines))
    vim.api.nvim_buf_set_extmark(bufnr, ns_id, cursor_line - 1, 0, {
      virt_lines = result_lines,
      virt_text_pos = "overlay",
    })
  end
end

---Shows completions as diff with highlighted changes
---@param completion Completion
---@return nil
function M.show_diff_completions(completion)
  logger.debug("ui.show_diff_completions")

  local bufnr = completion.bufnr

  local diff = completion.diff

  local original_start = diff[1]
  local original_len = diff[2]

  local original_end = original_start + original_len - 1

  if original_len ~= 0 then
    vim.api.nvim_buf_set_extmark(bufnr, ns_id, original_start - 1, 0, {
      line_hl_group = "DiffDelete",
      end_row = original_end - 1,
    })
  end

  local lines_to_replace = completion.lines_to_replace

  local virtual_lines = {}
  for _, line in ipairs(lines_to_replace) do
    table.insert(virtual_lines, { { line, "DiffAdd" } })
  end

  local insert_at = original_end - 1
  if original_len == 0 then
    insert_at = original_start - 1
  end

  if #virtual_lines > 0 then
    vim.api.nvim_buf_set_extmark(bufnr, ns_id, insert_at, 0, {
      virt_lines = virtual_lines,
      virt_lines_above = false,
    })
  end
end

return M
