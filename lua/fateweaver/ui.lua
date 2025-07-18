---@type fateweaver.Logger
local logger = require("fateweaver.logger")

---@class fateweaver.UI
---@field show_inline_completions fun(bufnr: integer, lines: string[]): nil
---@field show_addition fun(bufnr: integer, position: integer, lines: string[]): nil
---@field show_deletion fun(bufnr: integer, from: integer, to: integer): nil
---@field show_diff fun(bufnr: integer, from: integer, to: integer, lines: string[]): nil
---@field clear fun(bufnr: integer): nil
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
---@param bufnr integer
---@param lines string[]
---@return nil
function M.show_inline_completions(bufnr, lines)
  local cursor_pos = vim.api.nvim_win_get_cursor(0)

  local cursor_line = cursor_pos[1]
  local cursor_col = cursor_pos[2]

  local first_line_to_replace = lines[1]
  local first_line = first_line_to_replace:sub(cursor_col + 1, #first_line_to_replace)
  vim.api.nvim_buf_set_extmark(bufnr, ns_id, cursor_line - 1, cursor_col, {
    virt_text = { { first_line, "Comment" } },
    virt_text_pos = "overlay",
  })
  if #lines > 1 then
    local result_lines = {}
    for i = 2, #lines do
      table.insert(result_lines, { { lines[i], "Comment" } })
    end
    logger.debug("ResultLines:\n" .. vim.inspect(result_lines))
    vim.api.nvim_buf_set_extmark(bufnr, ns_id, cursor_line - 1, 0, {
      virt_lines = result_lines,
      virt_text_pos = "overlay",
    })
  end
end

---@param bufnr integer
---@param from integer
---@param to integer
---@param lines string[]
---@return nil
function M.show_diff(bufnr, from, to, lines)
  vim.api.nvim_buf_set_extmark(bufnr, ns_id, from - 1, 0, {
    line_hl_group = "DiffDelete",
    end_row = to - 2,
  })

  local virtual_lines = {}
  for _, line in ipairs(lines) do
    table.insert(virtual_lines, { { line, "DiffAdd" } })
  end

  vim.api.nvim_buf_set_extmark(bufnr, ns_id, to - 2, 0, {
    virt_lines = virtual_lines,
    virt_lines_above = false,
  })
end

---@param bufnr integer
---@param position integer
---@param lines string[]
---@return nil
function M.show_addition(bufnr, position, lines)
  local virtual_lines = {}
  for _, line in ipairs(lines) do
    table.insert(virtual_lines, { { line, "DiffAdd" } })
  end
  vim.api.nvim_buf_set_extmark(bufnr, ns_id, position - 1, 0, {
    virt_lines = virtual_lines,
    virt_lines_above = false,
  })
end

---@param bufnr integer
---@param from integer
---@param to integer
---@return nil
function M.show_deletion(bufnr, from, to)
  vim.api.nvim_buf_set_extmark(bufnr, ns_id, from - 1, 0, {
    line_hl_group = "DiffDelete",
    end_row = to - 2,
  })
end

return M
