local M = {}

local logger = require("fateweaver.logger")
local changes = require("fateweaver.changes")
local zeta_client = require("fateweaver.zeta_client")
local config = require("fateweaver.config")

function M.setup(opts)
  opts = opts or {}

  config.setup(opts)

  changes.setup()
end

function M.get_all_diffs()
  return changes.get_all_diffs()
end

local prompt_template =
"### Instruction:\nYou are a code completion assistant and your task is to analyze user edits and then rewrite an excerpt that the user provides, suggesting the appropriate edits within the excerpt, taking into account the cursor location.\n\n### User Edits:\n\n%s### User Excerpt:\n\n```%s\n%s\n```\n\n### Response:\n\n"

local edit_template = "User edited \"%s\":\n```diff\n%s\n```"

local function get_buffer_with_tokens(bufnr)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

  local cursor_pos = vim.api.nvim_win_get_cursor(0)
  local cursor_line = cursor_pos[1]
  local cursor_col = cursor_pos[2]

  local cursor_line_text = lines[cursor_line]
  if cursor_line_text then
    lines[cursor_line] = string.sub(cursor_line_text, 1, cursor_col) ..
        "<|user_cursor_is_here|>" ..
        string.sub(cursor_line_text, cursor_col + 1)
  end

  table.insert(lines, 1, "<|start_of_file|>")
  table.insert(lines, 2, "<|editable_region_start|>")
  table.insert(lines, "<|editable_region_end|>")
  table.insert(lines, "<|end_of_file|>")


  return table.concat(lines, "\n")
end

function M.test()
  local bufnr = vim.api.nvim_get_current_buf()
  local all_changes = changes.get_buffer_diffs(bufnr)
  local formatted_changes = ""
  for _, change in pairs(all_changes) do
    formatted_changes = formatted_changes .. string.format(edit_template, change.filename, change.diff) .. "\n\n"
  end


  local buffer_text = get_buffer_with_tokens(bufnr)

  local prompt = string.format(prompt_template, formatted_changes, vim.api.nvim_buf_get_name(bufnr), buffer_text)

  logger.debug(prompt)

  zeta_client.request_completion(prompt, function(res)

  end)
end

return M
