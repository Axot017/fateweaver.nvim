---@type fateweaver.Logger
local logger = require("fateweaver.logger")
---@type fateweaver.Config
local config = require("fateweaver.config")

---@class fateweaver.zeta.PromptHandler
---@field get_completion_lines fun(completion_str: string): string[] Extracts completion lines from LLM response
---@field get_buffer_with_tokens fun(bufnr: integer, editable_region: EditableRegion, cursor_pos: integer[]): string Prepares buffer content with special tokens
---@field get_prompt fun(bufnr: integer, editable_region: EditableRegion, cursor_pos: integer[], changes: Change[]): string Constructs the complete prompt
local M = {}

local start_file_token = "<|start_of_file|>"
local end_file_token = "<|end_of_file|>"
local start_editable_region_token = "<|editable_region_start|>"
local end_editable_region_token = "<|editable_region_end|>"
local user_cursor_token = "<|user_cursor_is_here|>"

local prompt_template =
"### Instruction:\nYou are a code completion assistant and your task is to analyze user edits and then rewrite an excerpt that the user provides, suggesting the appropriate edits within the excerpt, taking into account the cursor location.\n\n### User Edits:\n\n%s### User Excerpt:\n\n```%s\n%s\n```\n\n### Response:\n\n"

local edit_template = "User edited \"%s\":\n```diff\n%s\n```"

--- Extracts completion lines from the LLM response by removing special tokens
---@param completion_str string The raw completion string from the LLM
---@return string[] lines Array of completion lines
function M.get_completion_lines(completion_str)
  local start_pos = string.find(completion_str, start_editable_region_token, 1, true)
  local end_pos = string.find(completion_str, end_editable_region_token, 1, true)

  if not start_pos or not end_pos then
    return {}
  end

  local content_start = start_pos + string.len(start_editable_region_token)

  completion_str = string.sub(completion_str, content_start, end_pos - 1)

  if completion_str:sub(1, 1) == "\n" then
    completion_str = completion_str:sub(2)
  end

  if completion_str:sub(-1) == "\n" then
    completion_str = completion_str:sub(1, -2)
  end

  local completions = vim.split(completion_str, "\n")

  return completions
end

--- Prepares buffer content with special tokens for the LLM prompt
---@param bufnr integer The buffer number
---@param editable_region EditableRegion The region that can be edited
---@param cursor_pos integer[] Current cursor position {line, col}
---@return string formatted Formatted buffer content with tokens
function M.get_buffer_with_tokens(bufnr, editable_region, cursor_pos)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

  local cursor_line = cursor_pos[1]
  local cursor_col = cursor_pos[2]

  local cursor_line_text = lines[cursor_line]
  if cursor_line_text then
    lines[cursor_line] = string.sub(cursor_line_text, 1, cursor_col) ..
        user_cursor_token ..
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
    table.insert(result, start_file_token)
  end

  if start_line > editable_region.start_line then
    table.insert(result, start_editable_region_token)
  end

  for i, line in ipairs(included_lines) do
    local actual_line_num = start_line + i - 1

    if actual_line_num == editable_region.start_line then
      table.insert(result, start_editable_region_token)
    end

    table.insert(result, line)

    if actual_line_num == editable_region.end_line then
      table.insert(result, end_editable_region_token)
    end
  end

  if end_line < editable_region.end_line then
    table.insert(result, end_editable_region_token)
  end

  if end_line == #lines then
    table.insert(result, end_file_token)
  end

  return table.concat(result, "\n")
end

--- Constructs the full prompt for the LLM
---@param bufnr integer The buffer number
---@param editable_region EditableRegion The region that can be edited
---@param cursor_pos integer[] Current cursor position {line, col}
---@param changes Change[] Array of recorded changes to provide as context
---@return string prompt The complete prompt for the LLM
function M.get_prompt(bufnr, editable_region, cursor_pos, changes)
  local formatted_changes = ""
  for index, _ in ipairs(changes) do
    local change = changes[index]
    formatted_changes = formatted_changes .. string.format(edit_template, change.filename, change.diff) .. "\n\n"
  end

  local buffer_text = M.get_buffer_with_tokens(bufnr, editable_region, cursor_pos)

  local prompt = string.format(prompt_template, formatted_changes, vim.api.nvim_buf_get_name(bufnr), buffer_text)

  logger.debug("Prompt:\n\n" .. prompt)

  return prompt
end

return M
