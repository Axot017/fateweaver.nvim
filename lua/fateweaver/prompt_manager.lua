local logger = require("fateweaver.logger")
local config = require("fateweaver.config")

local prompt_template =
"### Instruction:\nYou are a code completion assistant and your task is to analyze user edits and then rewrite an excerpt that the user provides, suggesting the appropriate edits within the excerpt, taking into account the cursor location.\n\n### User Edits:\n\n%s### User Excerpt:\n\n```%s\n%s\n```\n\n### Response:\n\n"

local edit_template = "User edited \"%s\":\n```diff\n%s\n```"


local function get_buffer_with_tokens(bufnr, editable_region, cursor_pos)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

  local cursor_line = cursor_pos[1]
  local cursor_col = cursor_pos[2]

  local cursor_line_text = lines[cursor_line]
  if cursor_line_text then
    lines[cursor_line] = string.sub(cursor_line_text, 1, cursor_col) ..
        "<|user_cursor_is_here|>" ..
        string.sub(cursor_line_text, cursor_col + 1)
  end

  local context_offet = config.get().context_offset

  local start_line = math.max(1, cursor_line - context_offet)
  local end_line = math.min(#lines, cursor_line + context_offet)
  local included_lines = {}

  for i = start_line, end_line do
    table.insert(included_lines, lines[i])
  end

  local result = {}

  if start_line == 1 then
    table.insert(result, "<|start_of_file|>")
  end

  for i, line in ipairs(included_lines) do
    local actual_line_num = start_line + i - 1

    if actual_line_num == editable_region.start_line then
      table.insert(result, "<|editable_region_start|>")
    end

    table.insert(result, line)

    if actual_line_num == editable_region.end_line then
      table.insert(result, "<|editable_region_end|>")
    end
  end

  if end_line == #lines then
    table.insert(result, "<|end_of_file|>")
  end

  return table.concat(result, "\n")
end


local M = {}

function M.get_prompt(bufnr, editable_region, cursor_pos, changes)
  local formatted_changes = ""
  for _, change in pairs(changes) do
    formatted_changes = formatted_changes .. string.format(edit_template, change.filename, change.diff) .. "\n\n"
  end

  local buffer_text = get_buffer_with_tokens(bufnr, editable_region, cursor_pos)

  local prompt = string.format(prompt_template, formatted_changes, vim.api.nvim_buf_get_name(bufnr), buffer_text)

  logger.debug("Prompt:\n\n" .. prompt)

  return prompt
end

return M
